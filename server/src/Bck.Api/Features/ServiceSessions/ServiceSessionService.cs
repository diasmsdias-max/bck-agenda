using Npgsql;

namespace Bck.Api.Features.ServiceSessions;

public sealed class ServiceSessionService(IConfiguration configuration)
{
    private string ConnectionString => configuration.GetConnectionString("Postgres")
        ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")
        ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");

    public async Task<ServiceSessionSummary> OpenAsync(Guid groupId, Guid userId, OpenServiceSessionRequest request, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);

        Guid professionalId;
        Guid? clientId;
        string clientName;
        string? clientPhone;
        string appointmentStatus;

        const string appointmentSql = """
            SELECT a.professional_user_id,a.client_id,COALESCE(c.name,a.walk_in_name,'Cliente'),
                   COALESCE(c.phone,a.walk_in_phone),a.status
              FROM appointment a
              LEFT JOIN client c ON c.id=a.client_id AND c.group_id=a.group_id
             WHERE a.id=$1 AND a.group_id=$2
             FOR UPDATE OF a
            """;
        await using (var command = new NpgsqlCommand(appointmentSql, connection, transaction))
        {
            command.Parameters.AddWithValue(request.AppointmentId);
            command.Parameters.AddWithValue(groupId);
            await using var reader = await command.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) throw new KeyNotFoundException("APPOINTMENT_NOT_FOUND");
            professionalId = reader.GetGuid(0);
            clientId = reader.IsDBNull(1) ? null : reader.GetGuid(1);
            clientName = reader.GetString(2);
            clientPhone = reader.IsDBNull(3) ? null : reader.GetString(3);
            appointmentStatus = reader.GetString(4);
        }

        if (appointmentStatus is not ("CONFIRMED" or "WAITING"))
            throw new InvalidOperationException("APPOINTMENT_NOT_OPENABLE");

        await using (var actor = new NpgsqlCommand("SELECT 1 FROM bck_user WHERE id=$1 AND group_id=$2 AND active=true", connection, transaction))
        {
            actor.Parameters.AddWithValue(userId);
            actor.Parameters.AddWithValue(groupId);
            if (await actor.ExecuteScalarAsync(ct) is null) throw new UnauthorizedAccessException("USER_NOT_IN_GROUP");
        }

        Guid sessionId;
        const string insertSql = """
            INSERT INTO service_session(group_id,appointment_id,client_id,client_name_snapshot,client_phone_snapshot,
                professional_user_id,opened_by_user_id,notes)
            VALUES($1,$2,$3,$4,$5,$6,$7,$8)
            RETURNING id
            """;
        try
        {
            await using var insert = new NpgsqlCommand(insertSql, connection, transaction);
            insert.Parameters.AddWithValue(groupId);
            insert.Parameters.AddWithValue(request.AppointmentId);
            insert.Parameters.AddWithValue((object?)clientId ?? DBNull.Value);
            insert.Parameters.AddWithValue(clientName);
            insert.Parameters.AddWithValue((object?)clientPhone ?? DBNull.Value);
            insert.Parameters.AddWithValue(professionalId);
            insert.Parameters.AddWithValue(userId);
            insert.Parameters.AddWithValue((object?)request.Notes?.Trim() ?? DBNull.Value);
            sessionId = (Guid)(await insert.ExecuteScalarAsync(ct))!;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            throw new InvalidOperationException("SERVICE_SESSION_ALREADY_EXISTS", ex);
        }

        const string seedSql = """
            INSERT INTO service_session_item(group_id,service_session_id,item_type,service_id,name_snapshot,quantity,
                unit_price_snapshot,discount_amount,line_subtotal,line_total,added_by_user_id)
            SELECT $1,$2,'SERVICE',aps.service_id,s.name,1,aps.price_snapshot,0,aps.price_snapshot,aps.price_snapshot,$3
              FROM appointment_service aps
              JOIN service s ON s.id=aps.service_id AND s.group_id=$1
             WHERE aps.appointment_id=$4
             ORDER BY aps.sequence
            """;
        await using (var seed = new NpgsqlCommand(seedSql, connection, transaction))
        {
            seed.Parameters.AddWithValue(groupId);
            seed.Parameters.AddWithValue(sessionId);
            seed.Parameters.AddWithValue(userId);
            seed.Parameters.AddWithValue(request.AppointmentId);
            await seed.ExecuteNonQueryAsync(ct);
        }

        await using (var appointment = new NpgsqlCommand("UPDATE appointment SET status='IN_SERVICE',updated_at=now(),version=version+1 WHERE id=$1 AND group_id=$2 AND status=$3", connection, transaction))
        {
            appointment.Parameters.AddWithValue(request.AppointmentId);
            appointment.Parameters.AddWithValue(groupId);
            appointment.Parameters.AddWithValue(appointmentStatus);
            if (await appointment.ExecuteNonQueryAsync(ct) != 1) throw new InvalidOperationException("APPOINTMENT_NOT_OPENABLE");
        }
        await using (var history = new NpgsqlCommand("INSERT INTO appointment_status_history(group_id,appointment_id,from_status,to_status,changed_by_user_id,reason) VALUES($1,$2,$3,'IN_SERVICE',$4,'Atendimento iniciado')", connection, transaction))
        {
            history.Parameters.AddWithValue(groupId);
            history.Parameters.AddWithValue(request.AppointmentId);
            history.Parameters.AddWithValue(appointmentStatus);
            history.Parameters.AddWithValue(userId);
            await history.ExecuteNonQueryAsync(ct);
        }

        await RecalculateTotalsAsync(connection, transaction, groupId, sessionId, ct);
        await WriteHistoryAsync(connection, transaction, groupId, sessionId, userId, "OPENED", null, ct);
        await transaction.CommitAsync(ct);
        return (await GetAsync(groupId, sessionId, ct))!;
    }

    public async Task<ServiceSessionSummary?> GetByAppointmentAsync(Guid groupId, Guid appointmentId, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);
        const string sql = "SELECT id FROM service_session WHERE appointment_id=$1 AND group_id=$2";
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue(appointmentId);
        command.Parameters.AddWithValue(groupId);
        var value = await command.ExecuteScalarAsync(ct);
        return value is Guid sessionId ? await GetAsync(groupId, sessionId, ct) : null;
    }

    public async Task<ServiceSessionItemSummary> AddItemAsync(Guid groupId, Guid sessionId, Guid userId, AddServiceSessionItemRequest request, bool canDiscount, CancellationToken ct)
    {
        var itemType = request.ItemType.Trim().ToUpperInvariant();
        if (itemType is not ("SERVICE" or "PRODUCT")) throw new ArgumentException("ITEM_TYPE_INVALID");
        if (request.Quantity <= 0 || request.UnitPrice < 0 || request.DiscountAmount < 0) throw new ArgumentException("ITEM_VALUES_INVALID");
        var lineSubtotal = decimal.Round(request.Quantity * request.UnitPrice, 2, MidpointRounding.AwayFromZero);
        if (request.DiscountAmount > lineSubtotal) throw new ArgumentException("DISCOUNT_INVALID");
        if (request.DiscountAmount > 0 && !canDiscount) throw new UnauthorizedAccessException("DISCOUNT_NOT_ALLOWED");
        if (string.IsNullOrWhiteSpace(request.Name)) throw new ArgumentException("ITEM_NAME_REQUIRED");
        if (itemType == "SERVICE" && request.ServiceId is null) throw new ArgumentException("SERVICE_REQUIRED");

        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        await EnsureOpenSessionAsync(connection, transaction, groupId, sessionId, ct);

        if (itemType == "SERVICE")
        {
            await using var service = new NpgsqlCommand("SELECT 1 FROM service WHERE id=$1 AND group_id=$2 AND active=true", connection, transaction);
            service.Parameters.AddWithValue(request.ServiceId!.Value);
            service.Parameters.AddWithValue(groupId);
            if (await service.ExecuteScalarAsync(ct) is null) throw new ArgumentException("SERVICE_NOT_FOUND");
        }

        var lineTotal = lineSubtotal - request.DiscountAmount;
        Guid itemId;
        const string sql = """
            INSERT INTO service_session_item(group_id,service_session_id,item_type,service_id,source_item_id,name_snapshot,
                quantity,unit_price_snapshot,discount_amount,line_subtotal,line_total,added_by_user_id)
            VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id
            """;
        await using (var command = new NpgsqlCommand(sql, connection, transaction))
        {
            command.Parameters.AddWithValue(groupId); command.Parameters.AddWithValue(sessionId); command.Parameters.AddWithValue(itemType);
            command.Parameters.AddWithValue((object?)request.ServiceId ?? DBNull.Value); command.Parameters.AddWithValue((object?)request.SourceItemId ?? DBNull.Value);
            command.Parameters.AddWithValue(request.Name.Trim()); command.Parameters.AddWithValue(request.Quantity); command.Parameters.AddWithValue(request.UnitPrice);
            command.Parameters.AddWithValue(request.DiscountAmount); command.Parameters.AddWithValue(lineSubtotal); command.Parameters.AddWithValue(lineTotal); command.Parameters.AddWithValue(userId);
            itemId = (Guid)(await command.ExecuteScalarAsync(ct))!;
        }
        await RecalculateTotalsAsync(connection, transaction, groupId, sessionId, ct);
        await WriteHistoryAsync(connection, transaction, groupId, sessionId, userId, "ITEM_ADDED", $"{{\"itemId\":\"{itemId}\"}}", ct);
        await transaction.CommitAsync(ct);
        return new(itemId, itemType, request.ServiceId, request.SourceItemId, request.Name.Trim(), request.Quantity, request.UnitPrice, request.DiscountAmount, lineSubtotal, lineTotal);
    }

    public async Task<ServiceSessionSummary?> FinishAsync(Guid groupId, Guid sessionId, Guid userId, FinishServiceSessionRequest request, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        var appointmentId = await EnsureOpenSessionAsync(connection, transaction, groupId, sessionId, ct);
        await RecalculateTotalsAsync(connection, transaction, groupId, sessionId, ct);

        await using (var update = new NpgsqlCommand("UPDATE service_session SET status='FINISHED',notes=COALESCE($1,notes),finished_by_user_id=$2,finished_at=now(),updated_at=now(),version=version+1 WHERE id=$3 AND group_id=$4", connection, transaction))
        {
            update.Parameters.AddWithValue((object?)request.Notes?.Trim() ?? DBNull.Value); update.Parameters.AddWithValue(userId); update.Parameters.AddWithValue(sessionId); update.Parameters.AddWithValue(groupId);
            await update.ExecuteNonQueryAsync(ct);
        }
        await using (var appointment = new NpgsqlCommand("UPDATE appointment SET status='FINISHED',updated_at=now(),version=version+1 WHERE id=$1 AND group_id=$2 AND status='IN_SERVICE'", connection, transaction))
        {
            appointment.Parameters.AddWithValue(appointmentId); appointment.Parameters.AddWithValue(groupId);
            if (await appointment.ExecuteNonQueryAsync(ct) != 1) throw new InvalidOperationException("APPOINTMENT_MUST_BE_IN_SERVICE");
        }
        await using (var history = new NpgsqlCommand("INSERT INTO appointment_status_history(group_id,appointment_id,from_status,to_status,changed_by_user_id,reason) VALUES($1,$2,'IN_SERVICE','FINISHED',$3,'Atendimento finalizado')", connection, transaction))
        {
            history.Parameters.AddWithValue(groupId); history.Parameters.AddWithValue(appointmentId); history.Parameters.AddWithValue(userId); await history.ExecuteNonQueryAsync(ct);
        }
        await WriteHistoryAsync(connection, transaction, groupId, sessionId, userId, "FINISHED", null, ct);
        await transaction.CommitAsync(ct);
        return await GetAsync(groupId, sessionId, ct);
    }

    public async Task<ServiceSessionSummary?> GetAsync(Guid groupId, Guid sessionId, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct);
        const string sql = "SELECT id,appointment_id,professional_user_id,client_id,client_name_snapshot,client_phone_snapshot,status,notes,subtotal,discount_total,total,created_at,finished_at FROM service_session WHERE id=$1 AND group_id=$2";
        await using var command = new NpgsqlCommand(sql, connection); command.Parameters.AddWithValue(sessionId); command.Parameters.AddWithValue(groupId);
        await using var reader = await command.ExecuteReaderAsync(ct); if (!await reader.ReadAsync(ct)) return null;
        return new(reader.GetGuid(0),reader.GetGuid(1),reader.GetGuid(2),reader.IsDBNull(3)?null:reader.GetGuid(3),reader.GetString(4),reader.IsDBNull(5)?null:reader.GetString(5),reader.GetString(6),reader.IsDBNull(7)?null:reader.GetString(7),reader.GetDecimal(8),reader.GetDecimal(9),reader.GetDecimal(10),reader.GetFieldValue<DateTimeOffset>(11),reader.IsDBNull(12)?null:reader.GetFieldValue<DateTimeOffset>(12));
    }

    private static async Task<Guid> EnsureOpenSessionAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid groupId, Guid sessionId, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand("SELECT appointment_id,status FROM service_session WHERE id=$1 AND group_id=$2 FOR UPDATE", connection, transaction);
        command.Parameters.AddWithValue(sessionId); command.Parameters.AddWithValue(groupId); await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) throw new KeyNotFoundException("SERVICE_SESSION_NOT_FOUND");
        var appointmentId=reader.GetGuid(0); var status=reader.GetString(1); if(status is "FINISHED" or "CANCELLED") throw new InvalidOperationException("SERVICE_SESSION_CLOSED"); return appointmentId;
    }

    private static async Task RecalculateTotalsAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid groupId, Guid sessionId, CancellationToken ct)
    {
        const string sql = """
            UPDATE service_session s SET subtotal=x.subtotal,discount_total=x.discount,total=x.total,updated_at=now(),version=version+1
            FROM (SELECT COALESCE(sum(line_subtotal),0)::numeric(14,2) subtotal,COALESCE(sum(discount_amount),0)::numeric(14,2) discount,COALESCE(sum(line_total),0)::numeric(14,2) total FROM service_session_item WHERE service_session_id=$1 AND group_id=$2) x
            WHERE s.id=$1 AND s.group_id=$2
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction); command.Parameters.AddWithValue(sessionId); command.Parameters.AddWithValue(groupId); await command.ExecuteNonQueryAsync(ct);
    }

    private static async Task WriteHistoryAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid groupId, Guid sessionId, Guid userId, string action, string? afterJson, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand("INSERT INTO service_session_history(group_id,service_session_id,changed_by_user_id,action,after_json) VALUES($1,$2,$3,$4,CAST($5 AS jsonb))", connection, transaction);
        command.Parameters.AddWithValue(groupId); command.Parameters.AddWithValue(sessionId); command.Parameters.AddWithValue(userId); command.Parameters.AddWithValue(action); command.Parameters.AddWithValue((object?)afterJson ?? DBNull.Value); await command.ExecuteNonQueryAsync(ct);
    }
}
