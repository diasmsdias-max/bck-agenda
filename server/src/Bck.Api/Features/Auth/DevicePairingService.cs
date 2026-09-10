using System.Security.Cryptography;
using System.Text;
using Npgsql;

namespace Bck.Api.Features.Auth;

public sealed record CreatePairingRequest(string DeviceMode);
public sealed record CreatePairingResponse(string PairingCode, DateTimeOffset ExpiresAt);
public sealed record ConsumePairingRequest(string PairingCode, Guid DeviceId, string DeviceName, string Platform, string Username, string Password);
public sealed record ConsumePairingResponse(Guid GroupId, Guid DeviceId, Guid UserId, string DeviceMode);

public sealed class DevicePairingService(IConfiguration configuration)
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);

    public async Task<CreatePairingResponse> CreateAsync(Guid groupId, Guid userId, string mode, CancellationToken ct)
    {
        mode = mode.Trim().ToUpperInvariant();
        if (mode is not ("PERSONAL" or "SHARED"))
            throw new ArgumentException("Modo do dispositivo inválido.");

        var raw = Code();
        var now = DateTimeOffset.UtcNow;
        await using var connection = new NpgsqlConnection(Cs());
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("INSERT INTO device_pairing_token(group_id,created_by_user_id,token_hash,requested_device_mode,expires_at) VALUES($1,$2,$3,$4,$5)", connection);
        command.Parameters.AddWithValue(groupId);
        command.Parameters.AddWithValue(userId);
        command.Parameters.AddWithValue(Hash(raw));
        command.Parameters.AddWithValue(mode);
        command.Parameters.AddWithValue(now.Add(Lifetime));
        await command.ExecuteNonQueryAsync(ct);
        return new(raw, now.Add(Lifetime));
    }

    public async Task<ConsumePairingResponse?> ConsumeAsync(ConsumePairingRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.PairingCode) || request.DeviceId == Guid.Empty ||
            string.IsNullOrWhiteSpace(request.DeviceName) || string.IsNullOrWhiteSpace(request.Platform) ||
            string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrEmpty(request.Password))
            return null;

        await using var connection = new NpgsqlConnection(Cs());
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);

        Guid tokenId;
        Guid groupId;
        string mode;
        var tokenFound = false;
        await using (var command = new NpgsqlCommand("SELECT id,group_id,requested_device_mode FROM device_pairing_token WHERE token_hash=$1 AND consumed_at IS NULL AND expires_at>now() FOR UPDATE", connection, transaction))
        {
            command.Parameters.AddWithValue(Hash(request.PairingCode.Trim().ToUpperInvariant()));
            await using var reader = await command.ExecuteReaderAsync(ct);
            if (await reader.ReadAsync(ct))
            {
                tokenId = reader.GetGuid(0);
                groupId = reader.GetGuid(1);
                mode = reader.GetString(2);
                tokenFound = true;
            }
            else
            {
                tokenId = Guid.Empty;
                groupId = Guid.Empty;
                mode = string.Empty;
            }
        }
        if (!tokenFound)
        {
            await transaction.RollbackAsync(ct);
            return null;
        }

        Guid userId;
        string passwordHash;
        var userFound = false;
        await using (var command = new NpgsqlCommand("SELECT id,password_hash FROM bck_user WHERE group_id=$1 AND lower(username)=lower($2) AND active=true LIMIT 1", connection, transaction))
        {
            command.Parameters.AddWithValue(groupId);
            command.Parameters.AddWithValue(request.Username.Trim());
            await using var reader = await command.ExecuteReaderAsync(ct);
            if (await reader.ReadAsync(ct))
            {
                userId = reader.GetGuid(0);
                passwordHash = reader.GetString(1);
                userFound = true;
            }
            else
            {
                userId = Guid.Empty;
                passwordHash = string.Empty;
            }
        }
        if (!userFound || !PasswordHasher.Verify(request.Password, passwordHash))
        {
            await transaction.RollbackAsync(ct);
            return null;
        }

        await using (var command = new NpgsqlCommand("INSERT INTO device(id,group_id,name,platform,device_mode,status,is_principal) VALUES($1,$2,$3,$4,$5,'ACTIVE',false) ON CONFLICT(id) DO NOTHING", connection, transaction))
        {
            command.Parameters.AddWithValue(request.DeviceId);
            command.Parameters.AddWithValue(groupId);
            command.Parameters.AddWithValue(request.DeviceName.Trim());
            command.Parameters.AddWithValue(request.Platform.Trim().ToUpperInvariant());
            command.Parameters.AddWithValue(mode);
            if (await command.ExecuteNonQueryAsync(ct) != 1)
            {
                await transaction.RollbackAsync(ct);
                return null;
            }
        }

        await using (var command = new NpgsqlCommand("INSERT INTO device_user(device_id,user_id) VALUES($1,$2)", connection, transaction))
        {
            command.Parameters.AddWithValue(request.DeviceId);
            command.Parameters.AddWithValue(userId);
            await command.ExecuteNonQueryAsync(ct);
        }

        await using (var command = new NpgsqlCommand("UPDATE device_pairing_token SET consumed_at=now() WHERE id=$1 AND consumed_at IS NULL", connection, transaction))
        {
            command.Parameters.AddWithValue(tokenId);
            if (await command.ExecuteNonQueryAsync(ct) != 1)
            {
                await transaction.RollbackAsync(ct);
                return null;
            }
        }

        await transaction.CommitAsync(ct);
        return new(groupId, request.DeviceId, userId, mode);
    }

    private string Cs() => configuration.GetConnectionString("Postgres") ??
        Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION") ??
        throw new InvalidOperationException("PostgreSQL connection is not configured.");

    private static string Code()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var bytes = RandomNumberGenerator.GetBytes(8);
        var builder = new StringBuilder(9);
        for (var i = 0; i < 8; i++)
        {
            if (i == 4) builder.Append('-');
            builder.Append(chars[bytes[i] % chars.Length]);
        }
        return builder.ToString();
    }

    private static string Hash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
