using System.Security.Cryptography;
using Bck.Api.Infrastructure.Database;
using Npgsql;

namespace Bck.Api.Features.Bootstrap;

public sealed class BootstrapService(IConfiguration configuration)
{
    public async Task<BootstrapResponse> CreateCompanyAsync(CreateCompanyRequest request, CancellationToken ct)
    {
        Validate(request);

        var connectionString = configuration.GetConnectionString("Postgres")
            ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")
            ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");

        var groupId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var deviceId = Guid.Parse(request.DeviceId);
        var passwordHash = PasswordHasher.Hash(request.Password);
        var deviceMode = request.DeviceMode.Trim().ToUpperInvariant();

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);

        try
        {
            await using (var group = new NpgsqlCommand("""
                INSERT INTO bck_group (id, name, tax_id, phone)
                VALUES (@id, @name, @taxId, @phone)
                """, connection, transaction))
            {
                group.Parameters.AddWithValue("id", groupId);
                group.Parameters.AddWithValue("name", request.CompanyName.Trim());
                group.Parameters.AddWithValue("taxId", (object?)request.TaxId?.Trim() ?? DBNull.Value);
                group.Parameters.AddWithValue("phone", (object?)request.CompanyPhone?.Trim() ?? DBNull.Value);
                await group.ExecuteNonQueryAsync(ct);
            }

            await using (var user = new NpgsqlCommand("""
                INSERT INTO bck_user
                    (id, group_id, name, profile, is_owner, serves_clients, password_hash, username)
                VALUES
                    (@id, @groupId, @name, 'ADMIN', true, true, @passwordHash, @username)
                """, connection, transaction))
            {
                user.Parameters.AddWithValue("id", userId);
                user.Parameters.AddWithValue("groupId", groupId);
                user.Parameters.AddWithValue("name", request.OwnerName.Trim());
                user.Parameters.AddWithValue("passwordHash", passwordHash);
                user.Parameters.AddWithValue("username", request.OwnerUsername.Trim());
                await user.ExecuteNonQueryAsync(ct);
            }

            await using (var owner = new NpgsqlCommand(
                "UPDATE bck_group SET owner_user_id = @userId WHERE id = @groupId",
                connection, transaction))
            {
                owner.Parameters.AddWithValue("userId", userId);
                owner.Parameters.AddWithValue("groupId", groupId);
                await owner.ExecuteNonQueryAsync(ct);
            }

            await using (var device = new NpgsqlCommand("""
                INSERT INTO device
                    (id, group_id, name, platform, device_mode, is_principal, last_validated_at)
                VALUES
                    (@id, @groupId, @name, @platform, @mode, true, now())
                """, connection, transaction))
            {
                device.Parameters.AddWithValue("id", deviceId);
                device.Parameters.AddWithValue("groupId", groupId);
                device.Parameters.AddWithValue("name", request.DeviceName.Trim());
                device.Parameters.AddWithValue("platform", request.Platform.Trim().ToUpperInvariant());
                device.Parameters.AddWithValue("mode", deviceMode);
                await device.ExecuteNonQueryAsync(ct);
            }

            await using (var deviceUser = new NpgsqlCommand("""
                INSERT INTO device_user (device_id, user_id, quick_access_enabled)
                VALUES (@deviceId, @userId, false)
                """, connection, transaction))
            {
                deviceUser.Parameters.AddWithValue("deviceId", deviceId);
                deviceUser.Parameters.AddWithValue("userId", userId);
                await deviceUser.ExecuteNonQueryAsync(ct);
            }

            await transaction.CommitAsync(ct);
        }
        catch
        {
            await transaction.RollbackAsync(ct);
            throw;
        }

        return new(groupId, userId, deviceId, request.CompanyName.Trim(), request.OwnerName.Trim(), "ADMIN", true);
    }

    private static void Validate(CreateCompanyRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CompanyName)) throw new ArgumentException("CompanyName is required.");
        if (string.IsNullOrWhiteSpace(request.OwnerName)) throw new ArgumentException("OwnerName is required.");
        if (string.IsNullOrWhiteSpace(request.OwnerUsername)) throw new ArgumentException("OwnerUsername is required.");
        if (request.Password.Length < 8) throw new ArgumentException("Password must have at least 8 characters.");
        if (!Guid.TryParse(request.DeviceId, out _)) throw new ArgumentException("DeviceId must be a valid UUID.");
        if (string.IsNullOrWhiteSpace(request.DeviceName)) throw new ArgumentException("DeviceName is required.");
        if (string.IsNullOrWhiteSpace(request.Platform)) throw new ArgumentException("Platform is required.");
        if (request.DeviceMode.Trim().ToUpperInvariant() is not ("PERSONAL" or "SHARED"))
            throw new ArgumentException("DeviceMode must be PERSONAL or SHARED.");
    }
}

internal static class PasswordHasher
{
    private const int Iterations = 210_000;
    private const int SaltSize = 16;
    private const int KeySize = 32;

    public static string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var key = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, KeySize);
        return $"PBKDF2-SHA256${Iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(key)}";
    }
}
