using System.Security.Cryptography;
using System.Text;
using Npgsql;

namespace Bck.Api.Features.Auth;

public sealed record CreatePairingRequest(string DeviceMode);
public sealed record CreatePairingResponse(string PairingCode,DateTimeOffset ExpiresAt);
public sealed record ConsumePairingRequest(string PairingCode,Guid DeviceId,string DeviceName,string Platform);
public sealed record ConsumePairingResponse(Guid GroupId,Guid DeviceId,string DeviceMode);

public sealed class DevicePairingService(IConfiguration configuration)
{
    private static readonly TimeSpan Lifetime=TimeSpan.FromMinutes(10);
    public async Task<CreatePairingResponse> CreateAsync(Guid groupId,Guid userId,string mode,CancellationToken ct){mode=mode.Trim().ToUpperInvariant();if(mode is not("PERSONAL" or "SHARED"))throw new ArgumentException("Modo do dispositivo inválido.");var raw=CreateCode();var now=DateTimeOffset.UtcNow;await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var cmd=new NpgsqlCommand("INSERT INTO device_pairing_token(group_id,created_by_user_id,token_hash,requested_device_mode,expires_at) VALUES($1,$2,$3,$4,$5)",c);cmd.Parameters.AddWithValue(groupId);cmd.Parameters.AddWithValue(userId);cmd.Parameters.AddWithValue(Hash(raw));cmd.Parameters.AddWithValue(mode);cmd.Parameters.AddWithValue(now.Add(Lifetime));await cmd.ExecuteNonQueryAsync(ct);return new(raw,now.Add(Lifetime));}
    public async Task<ConsumePairingResponse?> ConsumeAsync(ConsumePairingRequest r,CancellationToken ct){if(string.IsNullOrWhiteSpace(r.PairingCode)||r.DeviceId==Guid.Empty||string.IsNullOrWhiteSpace(r.DeviceName)||string.IsNullOrWhiteSpace(r.Platform))return null;await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var tx=await c.BeginTransactionAsync(ct);Guid tokenId,groupId;string mode;await using(var q=new NpgsqlCommand("SELECT id,group_id,requested_device_mode FROM device_pairing_token WHERE token_hash=$1 AND consumed_at IS NULL AND expires_at>now() FOR UPDATE",c,tx)){q.Parameters.AddWithValue(Hash(r.PairingCode.Trim().ToUpperInvariant()));await using var rd=await q.ExecuteReaderAsync(ct);if(!await rd.ReadAsync(ct)){await tx.RollbackAsync(ct);return null;}tokenId=rd.GetGuid(0);groupId=rd.GetGuid(1);mode=rd.GetString(2);}await using(var ins=new NpgsqlCommand("INSERT INTO device(id,group_id,name,platform,device_mode,status,is_principal) VALUES($1,$2,$3,$4,$5,'ACTIVE',false) ON CONFLICT(id) DO NOTHING",c,tx)){ins.Parameters.AddWithValue(r.DeviceId);ins.Parameters.AddWithValue(groupId);ins.Parameters.AddWithValue(r.DeviceName.Trim());ins.Parameters.AddWithValue(r.Platform.Trim().ToUpperInvariant());ins.Parameters.AddWithValue(mode);if(await ins.ExecuteNonQueryAsync(ct)!=1){await tx.RollbackAsync(ct);return null;}}await using(var use=new NpgsqlCommand("UPDATE device_pairing_token SET consumed_at=now() WHERE id=$1 AND consumed_at IS NULL",c,tx)){use.Parameters.AddWithValue(tokenId);if(await use.ExecuteNonQueryAsync(ct)!=1){await tx.RollbackAsync(ct);return null;}}await tx.CommitAsync(ct);return new(groupId,r.DeviceId,mode);}
    private string Cs()=>configuration.GetConnectionString("Postgres")??Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")??throw new InvalidOperationException("PostgreSQL connection is not configured.");
    private static string CreateCode(){const string chars="ABCDEFGHJKLMNPQRSTUVWXYZ23456789";var bytes=RandomNumberGenerator.GetBytes(8);var b=new StringBuilder(9);for(var i=0;i<8;i++){if(i==4)b.Append('-');b.Append(chars[bytes[i]%chars.Length]);}return b.ToString();}
    private static string Hash(string token)=>Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
