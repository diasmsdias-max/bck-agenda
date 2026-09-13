using Npgsql;
using NpgsqlTypes;

namespace Bck.Api.Features.ServiceSessions;

public enum IdempotencyReservationState
{
    Reserved,
    Completed,
    InProgress,
    PayloadMismatch
}

public sealed record IdempotencyReservation(
    IdempotencyReservationState State,
    int? StatusCode = null,
    string? ResponseJson = null);

public sealed class ServiceSessionIdempotencyStore(IConfiguration configuration)
{
    private string ConnectionString => configuration.GetConnectionString("Postgres")
        ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")
        ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");

    public async Task<IdempotencyReservation> ReserveAsync(
        Guid groupId,
        Guid userId,
        string operation,
        string key,
        string requestHash,
        CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);

        const string insertSql = """
            INSERT INTO service_session_idempotency(group_id,user_id,operation,idempotency_key,request_hash)
            VALUES($1,$2,$3,$4,$5)
            ON CONFLICT (group_id,user_id,operation,idempotency_key) DO NOTHING
            RETURNING id
            """;
        await using (var insert = new NpgsqlCommand(insertSql, connection))
        {
            insert.Parameters.AddWithValue(groupId);
            insert.Parameters.AddWithValue(userId);
            insert.Parameters.AddWithValue(operation);
            insert.Parameters.AddWithValue(key);
            insert.Parameters.AddWithValue(requestHash);
            if (await insert.ExecuteScalarAsync(ct) is Guid)
                return new(IdempotencyReservationState.Reserved);
        }

        const string selectSql = """
            SELECT request_hash,status_code,response_json::text
              FROM service_session_idempotency
             WHERE group_id=$1 AND user_id=$2 AND operation=$3 AND idempotency_key=$4
            """;
        await using var select = new NpgsqlCommand(selectSql, connection);
        select.Parameters.AddWithValue(groupId);
        select.Parameters.AddWithValue(userId);
        select.Parameters.AddWithValue(operation);
        select.Parameters.AddWithValue(key);
        await using var reader = await select.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
            throw new InvalidOperationException("IDEMPOTENCY_RESERVATION_LOST");

        if (!string.Equals(reader.GetString(0), requestHash, StringComparison.Ordinal))
            return new(IdempotencyReservationState.PayloadMismatch);
        if (reader.IsDBNull(1))
            return new(IdempotencyReservationState.InProgress);
        return new(
            IdempotencyReservationState.Completed,
            reader.GetInt32(1),
            reader.IsDBNull(2) ? null : reader.GetString(2));
    }

    public async Task CompleteAsync(
        Guid groupId,
        Guid userId,
        string operation,
        string key,
        string requestHash,
        int statusCode,
        string responseJson,
        CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);
        const string sql = """
            UPDATE service_session_idempotency
               SET status_code=$1,response_json=$2,completed_at=now()
             WHERE group_id=$3 AND user_id=$4 AND operation=$5 AND idempotency_key=$6
               AND request_hash=$7 AND status_code IS NULL
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue(statusCode);
        command.Parameters.AddWithValue(NpgsqlDbType.Jsonb, responseJson);
        command.Parameters.AddWithValue(groupId);
        command.Parameters.AddWithValue(userId);
        command.Parameters.AddWithValue(operation);
        command.Parameters.AddWithValue(key);
        command.Parameters.AddWithValue(requestHash);
        if (await command.ExecuteNonQueryAsync(ct) != 1)
            throw new InvalidOperationException("IDEMPOTENCY_COMPLETION_FAILED");
    }

    public async Task ReleaseAsync(
        Guid groupId,
        Guid userId,
        string operation,
        string key,
        string requestHash,
        CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);
        const string sql = """
            DELETE FROM service_session_idempotency
             WHERE group_id=$1 AND user_id=$2 AND operation=$3 AND idempotency_key=$4
               AND request_hash=$5 AND status_code IS NULL
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue(groupId);
        command.Parameters.AddWithValue(userId);
        command.Parameters.AddWithValue(operation);
        command.Parameters.AddWithValue(key);
        command.Parameters.AddWithValue(requestHash);
        await command.ExecuteNonQueryAsync(ct);
    }
}
