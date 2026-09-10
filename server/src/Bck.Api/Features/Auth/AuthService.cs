using System.Security.Cryptography;
using System.Text;
using Npgsql;

namespace Bck.Api.Features.Auth;

public sealed class AuthService(IConfiguration configuration)
{
    private static readonly TimeSpan AccessTokenLifetime = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan RefreshTokenLifetime = TimeSpan.FromDays(30);
    private static readonly TimeSpan OfflineLeaseLifetime = TimeSpan.FromHours(24);

    public async Task<LoginResponse?> LoginAsync(LoginRequest request, CancellationToken ct)
    {
        if (request.GroupId == Guid.Empty || request.DeviceId == Guid.Empty || string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrEmpty(request.Password)) return null;
        var connectionString = GetConnectionString();
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);

        await using var command = new NpgsqlCommand("""
            SELECT u.id, u.name, u.profile, u.is_owner, u.must_change_password, u.password_hash, d.status, d.revoked_at
            FROM bck_user u
            JOIN device_user du ON du.user_id = u.id
            JOIN device d ON d.id = du.device_id AND d.group_id = u.group_id
            WHERE u.group_id = @groupId AND lower(u.username) = lower(@username) AND u.active = true AND d.id = @deviceId
            LIMIT 1
            """, connection);
        command.Parameters.AddWithValue("groupId", request.GroupId);
        command.Parameters.AddWithValue("username", request.Username.Trim());
        command.Parameters.AddWithValue("deviceId", request.DeviceId);

        Guid userId; string name; string profile; bool isOwner; bool mustChangePassword; string passwordHash; string deviceStatus; DateTimeOffset? revokedAt;
        await using (var reader = await command.ExecuteReaderAsync(ct))
        {
            if (!await reader.ReadAsync(ct)) return null;
            userId = reader.GetGuid(0); name = reader.GetString(1); profile = reader.GetString(2); isOwner = reader.GetBoolean(3);
            mustChangePassword = reader.GetBoolean(4); passwordHash = reader.GetString(5); deviceStatus = reader.GetString(6);
            revokedAt = reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7);
        }
        if (!string.Equals(deviceStatus, "ACTIVE", StringComparison.OrdinalIgnoreCase) || revokedAt is not null || !PasswordHasher.Verify(request.Password, passwordHash)) return null;

        var session = NewSession();
        await using var transaction = await connection.BeginTransactionAsync(ct);
        await InsertRefreshTokenAsync(connection, transaction, request.GroupId, userId, request.DeviceId, session.RefreshTokenHash, session.RefreshExpires, session.Now, null, ct);
        await using (var update = new NpgsqlCommand("""
            UPDATE bck_user SET last_login_at = @now, updated_at = @now WHERE id = @userId;
            UPDATE device SET last_validated_at = @now, updated_at = @now WHERE id = @deviceId;
            UPDATE device_user SET last_login_at = @now WHERE device_id = @deviceId AND user_id = @userId;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("now", session.Now); update.Parameters.AddWithValue("userId", userId); update.Parameters.AddWithValue("deviceId", request.DeviceId);
            await update.ExecuteNonQueryAsync(ct);
        }
        await transaction.CommitAsync(ct);
        return new(request.GroupId, userId, request.DeviceId, name, profile, isOwner, mustChangePassword, session.AccessToken, session.AccessExpires, session.RefreshToken, session.RefreshExpires, session.OfflineLeaseExpires);
    }

    public async Task<RefreshResponse?> RefreshAsync(RefreshRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken)) return null;
        var oldHash = HashToken(request.RefreshToken);
        await using var connection = new NpgsqlConnection(GetConnectionString());
        await connection.OpenAsync(ct);

        Guid oldId; Guid groupId; Guid userId; Guid deviceId;
        await using (var select = new NpgsqlCommand("""
            SELECT rt.id, rt.group_id, rt.user_id, rt.device_id
            FROM refresh_token rt
            JOIN bck_user u ON u.id = rt.user_id AND u.active = true
            JOIN device d ON d.id = rt.device_id AND d.status = 'ACTIVE' AND d.revoked_at IS NULL
            WHERE rt.token_hash = @hash AND rt.revoked_at IS NULL AND rt.expires_at > now()
            LIMIT 1
            """, connection))
        {
            select.Parameters.AddWithValue("hash", oldHash);
            await using var reader = await select.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) return null;
            oldId = reader.GetGuid(0); groupId = reader.GetGuid(1); userId = reader.GetGuid(2); deviceId = reader.GetGuid(3);
        }

        var session = NewSession();
        var newId = Guid.NewGuid();
        await using var transaction = await connection.BeginTransactionAsync(ct);
        await InsertRefreshTokenAsync(connection, transaction, groupId, userId, deviceId, session.RefreshTokenHash, session.RefreshExpires, session.Now, newId, ct);
        await using (var revoke = new NpgsqlCommand("""
            UPDATE refresh_token SET revoked_at = @now, replaced_by_token_id = @newId, last_used_at = @now
            WHERE id = @oldId AND revoked_at IS NULL
            """, connection, transaction))
        {
            revoke.Parameters.AddWithValue("now", session.Now); revoke.Parameters.AddWithValue("newId", newId); revoke.Parameters.AddWithValue("oldId", oldId);
            if (await revoke.ExecuteNonQueryAsync(ct) != 1) { await transaction.RollbackAsync(ct); return null; }
        }
        await using (var device = new NpgsqlCommand("UPDATE device SET last_validated_at = @now, updated_at = @now WHERE id = @deviceId", connection, transaction))
        {
            device.Parameters.AddWithValue("now", session.Now); device.Parameters.AddWithValue("deviceId", deviceId); await device.ExecuteNonQueryAsync(ct);
        }
        await transaction.CommitAsync(ct);
        return new(session.AccessToken, session.AccessExpires, session.RefreshToken, session.RefreshExpires, session.OfflineLeaseExpires);
    }

    public async Task LogoutAsync(LogoutRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken)) return;
        await using var connection = new NpgsqlConnection(GetConnectionString());
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("UPDATE refresh_token SET revoked_at = COALESCE(revoked_at, now()) WHERE token_hash = @hash", connection);
        command.Parameters.AddWithValue("hash", HashToken(request.RefreshToken));
        await command.ExecuteNonQueryAsync(ct);
    }

    private string GetConnectionString() => configuration.GetConnectionString("Postgres") ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION") ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");

    private static async Task InsertRefreshTokenAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid groupId, Guid userId, Guid deviceId, string tokenHash, DateTimeOffset expiresAt, DateTimeOffset now, Guid? explicitId, CancellationToken ct)
    {
        await using var insert = new NpgsqlCommand("""
            INSERT INTO refresh_token (id, group_id, user_id, device_id, token_hash, expires_at, last_used_at)
            VALUES (@id, @groupId, @userId, @deviceId, @tokenHash, @expiresAt, @now)
            """, connection, transaction);
        insert.Parameters.AddWithValue("id", explicitId ?? Guid.NewGuid()); insert.Parameters.AddWithValue("groupId", groupId); insert.Parameters.AddWithValue("userId", userId);
        insert.Parameters.AddWithValue("deviceId", deviceId); insert.Parameters.AddWithValue("tokenHash", tokenHash); insert.Parameters.AddWithValue("expiresAt", expiresAt); insert.Parameters.AddWithValue("now", now);
        await insert.ExecuteNonQueryAsync(ct);
    }

    private static SessionTokens NewSession()
    {
        var now = DateTimeOffset.UtcNow; var refresh = CreateOpaqueToken(48);
        return new(now, CreateOpaqueToken(32), now.Add(AccessTokenLifetime), refresh, HashToken(refresh), now.Add(RefreshTokenLifetime), now.Add(OfflineLeaseLifetime));
    }
    private static string CreateOpaqueToken(int bytes) => Convert.ToBase64String(RandomNumberGenerator.GetBytes(bytes));
    private static string HashToken(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    private sealed record SessionTokens(DateTimeOffset Now, string AccessToken, DateTimeOffset AccessExpires, string RefreshToken, string RefreshTokenHash, DateTimeOffset RefreshExpires, DateTimeOffset OfflineLeaseExpires);
}
