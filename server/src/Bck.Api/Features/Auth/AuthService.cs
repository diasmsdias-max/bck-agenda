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
        if (request.GroupId == Guid.Empty || request.DeviceId == Guid.Empty ||
            string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrEmpty(request.Password))
            return null;

        var connectionString = configuration.GetConnectionString("Postgres")
            ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")
            ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);

        await using var command = new NpgsqlCommand("""
            SELECT u.id, u.name, u.profile, u.is_owner, u.must_change_password, u.password_hash,
                   d.status, d.revoked_at
            FROM bck_user u
            JOIN device_user du ON du.user_id = u.id
            JOIN device d ON d.id = du.device_id AND d.group_id = u.group_id
            WHERE u.group_id = @groupId
              AND lower(u.username) = lower(@username)
              AND u.active = true
              AND d.id = @deviceId
            LIMIT 1
            """, connection);
        command.Parameters.AddWithValue("groupId", request.GroupId);
        command.Parameters.AddWithValue("username", request.Username.Trim());
        command.Parameters.AddWithValue("deviceId", request.DeviceId);

        Guid userId;
        string name;
        string profile;
        bool isOwner;
        bool mustChangePassword;
        string passwordHash;
        string deviceStatus;
        DateTimeOffset? revokedAt;

        await using (var reader = await command.ExecuteReaderAsync(ct))
        {
            if (!await reader.ReadAsync(ct)) return null;
            userId = reader.GetGuid(0);
            name = reader.GetString(1);
            profile = reader.GetString(2);
            isOwner = reader.GetBoolean(3);
            mustChangePassword = reader.GetBoolean(4);
            passwordHash = reader.GetString(5);
            deviceStatus = reader.GetString(6);
            revokedAt = reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7);
        }

        if (!string.Equals(deviceStatus, "ACTIVE", StringComparison.OrdinalIgnoreCase) || revokedAt is not null)
            return null;
        if (!PasswordHasher.Verify(request.Password, passwordHash)) return null;

        var now = DateTimeOffset.UtcNow;
        var accessExpires = now.Add(AccessTokenLifetime);
        var refreshExpires = now.Add(RefreshTokenLifetime);
        var offlineLeaseExpires = now.Add(OfflineLeaseLifetime);
        var accessToken = CreateOpaqueToken(32);
        var refreshToken = CreateOpaqueToken(48);
        var refreshHash = HashToken(refreshToken);

        await using var transaction = await connection.BeginTransactionAsync(ct);
        await using (var insert = new NpgsqlCommand("""
            INSERT INTO refresh_token
                (group_id, user_id, device_id, token_hash, expires_at, last_used_at)
            VALUES
                (@groupId, @userId, @deviceId, @tokenHash, @expiresAt, @now)
            """, connection, transaction))
        {
            insert.Parameters.AddWithValue("groupId", request.GroupId);
            insert.Parameters.AddWithValue("userId", userId);
            insert.Parameters.AddWithValue("deviceId", request.DeviceId);
            insert.Parameters.AddWithValue("tokenHash", refreshHash);
            insert.Parameters.AddWithValue("expiresAt", refreshExpires);
            insert.Parameters.AddWithValue("now", now);
            await insert.ExecuteNonQueryAsync(ct);
        }

        await using (var update = new NpgsqlCommand("""
            UPDATE bck_user SET last_login_at = @now, updated_at = @now WHERE id = @userId;
            UPDATE device SET last_validated_at = @now, updated_at = @now WHERE id = @deviceId;
            UPDATE device_user SET last_login_at = @now WHERE device_id = @deviceId AND user_id = @userId;
            """, connection, transaction))
        {
            update.Parameters.AddWithValue("now", now);
            update.Parameters.AddWithValue("userId", userId);
            update.Parameters.AddWithValue("deviceId", request.DeviceId);
            await update.ExecuteNonQueryAsync(ct);
        }

        await transaction.CommitAsync(ct);

        return new(request.GroupId, userId, request.DeviceId, name, profile, isOwner,
            mustChangePassword, accessToken, accessExpires, refreshToken, refreshExpires, offlineLeaseExpires);
    }

    private static string CreateOpaqueToken(int bytes) =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(bytes));

    private static string HashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
