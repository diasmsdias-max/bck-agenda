using Npgsql;

namespace Bck.Api.Features.Auth;

public sealed record DeviceListItem(Guid Id, string Name, string Platform, string DeviceMode, string Status, bool IsPrincipal, DateTimeOffset? LastValidatedAt, DateTimeOffset? LastLoginAt, int LinkedUsers);
public sealed record UpdateDeviceModeRequest(string DeviceMode);

public sealed class DeviceManagementService(IConfiguration configuration)
{
    public async Task<IReadOnlyList<DeviceListItem>> ListAsync(Guid groupId, CancellationToken ct)
    {
        var result = new List<DeviceListItem>();
        await using var connection = new NpgsqlConnection(Cs());
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            SELECT d.id,d.name,d.platform,d.device_mode,d.status,d.is_principal,d.last_validated_at,
                   max(du.last_login_at),count(du.user_id)::int
            FROM device d
            LEFT JOIN device_user du ON du.device_id=d.id
            WHERE d.group_id=$1
            GROUP BY d.id
            ORDER BY d.is_principal DESC,d.created_at,d.name
            """, connection);
        command.Parameters.AddWithValue(groupId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            result.Add(new(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetBoolean(5), reader.IsDBNull(6) ? null : reader.GetFieldValue<DateTimeOffset>(6), reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7), reader.GetInt32(8)));
        return result;
    }

    public async Task<bool> RevokeAsync(Guid groupId, Guid deviceId, Guid actorUserId, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(Cs());
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        var changed = await ExecuteAsync(connection, transaction, "UPDATE device SET status='REVOKED',revoked_at=now(),security_version=security_version+1,version=version+1,updated_at=now() WHERE id=$1 AND group_id=$2 AND is_principal=false AND status<>'REVOKED'", deviceId, groupId, ct);
        if (!changed) { await transaction.RollbackAsync(ct); return false; }
        await AuditAsync(connection, transaction, groupId, actorUserId, deviceId, "DEVICE_REVOKED", ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    public async Task<bool> ChangeModeAsync(Guid groupId, Guid deviceId, Guid actorUserId, string mode, CancellationToken ct)
    {
        mode = mode.Trim().ToUpperInvariant();
        if (mode is not ("PERSONAL" or "SHARED")) throw new ArgumentException("Modo do dispositivo inválido.");
        await using var connection = new NpgsqlConnection(Cs());
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        var changed = await ExecuteAsync(connection, transaction, "UPDATE device SET device_mode=$3,security_version=security_version+1,version=version+1,updated_at=now() WHERE id=$1 AND group_id=$2 AND status='ACTIVE' AND device_mode<>$3", deviceId, groupId, ct, mode);
        if (!changed) { await transaction.RollbackAsync(ct); return false; }
        await using (var quick = new NpgsqlCommand("UPDATE device_user SET quick_access_enabled=false WHERE device_id=$1", connection, transaction)) { quick.Parameters.AddWithValue(deviceId); await quick.ExecuteNonQueryAsync(ct); }
        await AuditAsync(connection, transaction, groupId, actorUserId, deviceId, "DEVICE_MODE_CHANGED", ct, mode);
        await transaction.CommitAsync(ct);
        return true;
    }

    private static async Task<bool> ExecuteAsync(NpgsqlConnection c, NpgsqlTransaction t, string sql, Guid deviceId, Guid groupId, CancellationToken ct, string? mode=null)
    {
        await using var command = new NpgsqlCommand(sql,c,t); command.Parameters.AddWithValue(deviceId); command.Parameters.AddWithValue(groupId); if(mode!=null) command.Parameters.AddWithValue(mode); return await command.ExecuteNonQueryAsync(ct)==1;
    }
    private static async Task AuditAsync(NpgsqlConnection c,NpgsqlTransaction t,Guid groupId,Guid userId,Guid deviceId,string action,CancellationToken ct,string? mode=null)
    {
        await using var command=new NpgsqlCommand("INSERT INTO audit_log(group_id,user_id,action,entity_type,entity_id,after_json) VALUES($1,$2,$3,'DEVICE',$4,CASE WHEN $5::text IS NULL THEN NULL ELSE jsonb_build_object('deviceMode',$5::text) END)",c,t);command.Parameters.AddWithValue(groupId);command.Parameters.AddWithValue(userId);command.Parameters.AddWithValue(action);command.Parameters.AddWithValue(deviceId);command.Parameters.AddWithValue((object?)mode??DBNull.Value);await command.ExecuteNonQueryAsync(ct);
    }
    private string Cs()=>configuration.GetConnectionString("Postgres")??Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")??throw new InvalidOperationException("PostgreSQL connection is not configured.");
}
