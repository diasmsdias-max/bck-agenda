using System.Security.Cryptography;
using System.Text;
using Npgsql;

namespace Bck.Api.Features.Auth;

public sealed class AuthService(IConfiguration configuration, JwtTokenService jwtTokens)
{
    private static readonly TimeSpan RefreshTokenLifetime = TimeSpan.FromDays(30);
    private static readonly TimeSpan OfflineLeaseLifetime = TimeSpan.FromHours(24);

    public async Task<LoginResponse?> LoginAsync(LoginRequest request, CancellationToken ct)
    {
        if (request.GroupId == Guid.Empty || request.DeviceId == Guid.Empty || string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrEmpty(request.Password)) return null;
        await using var connection = new NpgsqlConnection(GetConnectionString()); await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            SELECT u.id,u.name,u.profile,u.is_owner,u.must_change_password,u.password_hash,d.status,d.revoked_at,u.permission_version,d.security_version
            FROM bck_user u JOIN device_user du ON du.user_id=u.id JOIN device d ON d.id=du.device_id AND d.group_id=u.group_id
            WHERE u.group_id=@groupId AND lower(u.username)=lower(@username) AND u.active=true AND d.id=@deviceId LIMIT 1
            """, connection);
        command.Parameters.AddWithValue("groupId",request.GroupId);command.Parameters.AddWithValue("username",request.Username.Trim());command.Parameters.AddWithValue("deviceId",request.DeviceId);
        Guid userId;string name,profile,passwordHash,deviceStatus;bool isOwner,mustChangePassword;DateTimeOffset? revokedAt;int permissionVersion,securityVersion;
        await using(var reader=await command.ExecuteReaderAsync(ct)){if(!await reader.ReadAsync(ct))return null;userId=reader.GetGuid(0);name=reader.GetString(1);profile=reader.GetString(2);isOwner=reader.GetBoolean(3);mustChangePassword=reader.GetBoolean(4);passwordHash=reader.GetString(5);deviceStatus=reader.GetString(6);revokedAt=reader.IsDBNull(7)?null:reader.GetFieldValue<DateTimeOffset>(7);permissionVersion=reader.GetInt32(8);securityVersion=reader.GetInt32(9);}
        if(!string.Equals(deviceStatus,"ACTIVE",StringComparison.OrdinalIgnoreCase)||revokedAt is not null||!PasswordHasher.Verify(request.Password,passwordHash))return null;
        var now=DateTimeOffset.UtcNow;var refresh=CreateOpaqueToken(48);var refreshHash=HashToken(refresh);var refreshExpires=now.Add(RefreshTokenLifetime);var lease=now.Add(OfflineLeaseLifetime);var access=jwtTokens.Create(new(request.GroupId,userId,request.DeviceId,profile,isOwner,permissionVersion,securityVersion),now,out var accessExpires);
        await using var tx=await connection.BeginTransactionAsync(ct);await InsertRefreshTokenAsync(connection,tx,request.GroupId,userId,request.DeviceId,refreshHash,refreshExpires,now,null,ct);
        await using(var update=new NpgsqlCommand("UPDATE bck_user SET last_login_at=@now,updated_at=@now WHERE id=@u; UPDATE device SET last_validated_at=@now,updated_at=@now WHERE id=@d; UPDATE device_user SET last_login_at=@now WHERE device_id=@d AND user_id=@u;",connection,tx)){update.Parameters.AddWithValue("now",now);update.Parameters.AddWithValue("u",userId);update.Parameters.AddWithValue("d",request.DeviceId);await update.ExecuteNonQueryAsync(ct);}await tx.CommitAsync(ct);
        return new(request.GroupId,userId,request.DeviceId,name,profile,isOwner,mustChangePassword,access,accessExpires,refresh,refreshExpires,lease);
    }

    public async Task<RefreshResponse?> RefreshAsync(RefreshRequest request,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(request.RefreshToken))return null;var oldHash=HashToken(request.RefreshToken);await using var connection=new NpgsqlConnection(GetConnectionString());await connection.OpenAsync(ct);
        Guid oldId,groupId,userId,deviceId;string profile;bool isOwner;int permissionVersion,securityVersion;
        await using(var select=new NpgsqlCommand("""
            SELECT rt.id,rt.group_id,rt.user_id,rt.device_id,u.profile,u.is_owner,u.permission_version,d.security_version
            FROM refresh_token rt JOIN bck_user u ON u.id=rt.user_id AND u.active=true JOIN device d ON d.id=rt.device_id AND d.status='ACTIVE' AND d.revoked_at IS NULL
            WHERE rt.token_hash=@hash AND rt.revoked_at IS NULL AND rt.expires_at>now() LIMIT 1
            """,connection)){select.Parameters.AddWithValue("hash",oldHash);await using var reader=await select.ExecuteReaderAsync(ct);if(!await reader.ReadAsync(ct))return null;oldId=reader.GetGuid(0);groupId=reader.GetGuid(1);userId=reader.GetGuid(2);deviceId=reader.GetGuid(3);profile=reader.GetString(4);isOwner=reader.GetBoolean(5);permissionVersion=reader.GetInt32(6);securityVersion=reader.GetInt32(7);}
        var now=DateTimeOffset.UtcNow;var refresh=CreateOpaqueToken(48);var refreshExpires=now.Add(RefreshTokenLifetime);var lease=now.Add(OfflineLeaseLifetime);var access=jwtTokens.Create(new(groupId,userId,deviceId,profile,isOwner,permissionVersion,securityVersion),now,out var accessExpires);var newId=Guid.NewGuid();
        await using var tx=await connection.BeginTransactionAsync(ct);await InsertRefreshTokenAsync(connection,tx,groupId,userId,deviceId,HashToken(refresh),refreshExpires,now,newId,ct);
        await using(var revoke=new NpgsqlCommand("UPDATE refresh_token SET revoked_at=@now,replaced_by_token_id=@newId,last_used_at=@now WHERE id=@oldId AND revoked_at IS NULL",connection,tx)){revoke.Parameters.AddWithValue("now",now);revoke.Parameters.AddWithValue("newId",newId);revoke.Parameters.AddWithValue("oldId",oldId);if(await revoke.ExecuteNonQueryAsync(ct)!=1){await tx.RollbackAsync(ct);return null;}}
        await using(var device=new NpgsqlCommand("UPDATE device SET last_validated_at=@now,updated_at=@now WHERE id=@d",connection,tx)){device.Parameters.AddWithValue("now",now);device.Parameters.AddWithValue("d",deviceId);await device.ExecuteNonQueryAsync(ct);}await tx.CommitAsync(ct);return new(access,accessExpires,refresh,refreshExpires,lease);
    }

    public async Task LogoutAsync(LogoutRequest request,CancellationToken ct){if(string.IsNullOrWhiteSpace(request.RefreshToken))return;await using var c=new NpgsqlConnection(GetConnectionString());await c.OpenAsync(ct);await using var cmd=new NpgsqlCommand("UPDATE refresh_token SET revoked_at=COALESCE(revoked_at,now()) WHERE token_hash=@hash",c);cmd.Parameters.AddWithValue("hash",HashToken(request.RefreshToken));await cmd.ExecuteNonQueryAsync(ct);}
    private string GetConnectionString()=>configuration.GetConnectionString("Postgres")??Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")??throw new InvalidOperationException("PostgreSQL connection is not configured.");
    private static async Task InsertRefreshTokenAsync(NpgsqlConnection c,NpgsqlTransaction tx,Guid g,Guid u,Guid d,string hash,DateTimeOffset expires,DateTimeOffset now,Guid? id,CancellationToken ct){await using var cmd=new NpgsqlCommand("INSERT INTO refresh_token(id,group_id,user_id,device_id,token_hash,expires_at,last_used_at) VALUES(@id,@g,@u,@d,@h,@e,@n)",c,tx);cmd.Parameters.AddWithValue("id",id??Guid.NewGuid());cmd.Parameters.AddWithValue("g",g);cmd.Parameters.AddWithValue("u",u);cmd.Parameters.AddWithValue("d",d);cmd.Parameters.AddWithValue("h",hash);cmd.Parameters.AddWithValue("e",expires);cmd.Parameters.AddWithValue("n",now);await cmd.ExecuteNonQueryAsync(ct);}
    private static string CreateOpaqueToken(int bytes)=>Convert.ToBase64String(RandomNumberGenerator.GetBytes(bytes));private static string HashToken(string token)=>Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
