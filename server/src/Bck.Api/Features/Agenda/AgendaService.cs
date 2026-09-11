using Npgsql;

namespace Bck.Api.Features.Agenda;

public sealed record CreateClientRequest(Guid GroupId, string Name, string Phone, Guid CreatedByUserId, bool WhatsAppEnabled = true, string? Notes = null);
public sealed record ClientSummary(Guid Id, string Name, string Phone, bool WhatsAppEnabled);
public sealed record CreateServiceRequest(Guid GroupId, string Name, decimal StandardPrice, int StandardDurationMinutes, string? Description = null);
public sealed record ServiceSummary(Guid Id, string Name, decimal StandardPrice, int StandardDurationMinutes);
public sealed record CreateAppointmentRequest(Guid GroupId, Guid ProfessionalUserId, Guid CreatedByUserId, Guid? ClientId, string? WalkInName, string? WalkInPhone, DateTimeOffset StartsAt, int DurationMinutes, Guid ServiceId, bool IsFitIn = false, string? Notes = null, bool ForceConflict = false);
public sealed record AppointmentSummary(Guid Id, Guid ProfessionalUserId, Guid? ClientId, string ClientName, DateTimeOffset StartsAt, DateTimeOffset EndsAt, string Status, bool IsFitIn);
public sealed record AvailabilityResponse(bool Available, IReadOnlyList<AppointmentSummary> Conflicts);
public sealed record ChangeAppointmentStatusRequest(string Status, string? Reason = null);
public sealed record RescheduleAppointmentRequest(Guid ProfessionalUserId, DateTimeOffset StartsAt, int DurationMinutes, string? Reason = null, bool ForceConflict = false);
public sealed record RescheduleAppointmentResult(Guid OriginalAppointmentId, AppointmentSummary NewAppointment);

public sealed class AgendaService(IConfiguration configuration)
{
    private string ConnectionString => configuration.GetConnectionString("Postgres") ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION") ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");
    private static readonly HashSet<string> AppointmentStatuses = new(StringComparer.OrdinalIgnoreCase) { "SCHEDULED", "CONFIRMED", "WAITING", "IN_SERVICE", "FINISHED", "CANCELLED", "NO_SHOW", "RESCHEDULED" };
    private static readonly Dictionary<string, HashSet<string>> AllowedTransitions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["SCHEDULED"] = new(StringComparer.OrdinalIgnoreCase) { "CONFIRMED", "WAITING", "CANCELLED", "NO_SHOW", "RESCHEDULED" },
        ["CONFIRMED"] = new(StringComparer.OrdinalIgnoreCase) { "WAITING", "IN_SERVICE", "CANCELLED", "NO_SHOW", "RESCHEDULED" },
        ["WAITING"] = new(StringComparer.OrdinalIgnoreCase) { "IN_SERVICE", "CANCELLED", "NO_SHOW", "RESCHEDULED" },
        ["IN_SERVICE"] = new(StringComparer.OrdinalIgnoreCase) { "FINISHED", "CANCELLED" },
        ["FINISHED"] = new(StringComparer.OrdinalIgnoreCase), ["CANCELLED"] = new(StringComparer.OrdinalIgnoreCase), ["NO_SHOW"] = new(StringComparer.OrdinalIgnoreCase), ["RESCHEDULED"] = new(StringComparer.OrdinalIgnoreCase)
    };

    public async Task<ClientSummary> CreateClientAsync(CreateClientRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name) || string.IsNullOrWhiteSpace(request.Phone)) throw new ArgumentException("Nome e telefone são obrigatórios.");
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("INSERT INTO client(group_id,name,phone,whatsapp_enabled,notes,created_by_user_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id", connection);
        command.Parameters.AddWithValue(request.GroupId); command.Parameters.AddWithValue(request.Name.Trim()); command.Parameters.AddWithValue(request.Phone.Trim()); command.Parameters.AddWithValue(request.WhatsAppEnabled); command.Parameters.AddWithValue((object?)request.Notes ?? DBNull.Value); command.Parameters.AddWithValue(request.CreatedByUserId);
        var id = (Guid)(await command.ExecuteScalarAsync(ct))!; return new(id, request.Name.Trim(), request.Phone.Trim(), request.WhatsAppEnabled);
    }

    public async Task<IReadOnlyList<ClientSummary>> SearchClientsAsync(Guid groupId, string? query, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct);
        const string sql = "SELECT id,name,phone,whatsapp_enabled FROM client WHERE group_id=$1 AND active=true AND ($2='' OR name ILIKE '%'||$2||'%' OR phone ILIKE '%'||$2||'%') ORDER BY name LIMIT 50";
        await using var command = new NpgsqlCommand(sql, connection); command.Parameters.AddWithValue(groupId); command.Parameters.AddWithValue(query?.Trim() ?? "");
        await using var reader = await command.ExecuteReaderAsync(ct); var result = new List<ClientSummary>(); while (await reader.ReadAsync(ct)) result.Add(new(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetBoolean(3))); return result;
    }

    public async Task<ServiceSummary> CreateServiceAsync(CreateServiceRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name) || request.StandardDurationMinutes <= 0 || request.StandardPrice < 0) throw new ArgumentException("Serviço, duração e preço são inválidos.");
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("INSERT INTO service(group_id,name,description,standard_price,standard_duration_minutes) VALUES($1,$2,$3,$4,$5) RETURNING id", connection);
        command.Parameters.AddWithValue(request.GroupId); command.Parameters.AddWithValue(request.Name.Trim()); command.Parameters.AddWithValue((object?)request.Description ?? DBNull.Value); command.Parameters.AddWithValue(request.StandardPrice); command.Parameters.AddWithValue(request.StandardDurationMinutes);
        var id = (Guid)(await command.ExecuteScalarAsync(ct))!; return new(id, request.Name.Trim(), request.StandardPrice, request.StandardDurationMinutes);
    }

    public async Task<IReadOnlyList<ServiceSummary>> ListServicesAsync(Guid groupId, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("SELECT id,name,standard_price,standard_duration_minutes FROM service WHERE group_id=$1 AND active=true ORDER BY name", connection); command.Parameters.AddWithValue(groupId);
        await using var reader = await command.ExecuteReaderAsync(ct); var result = new List<ServiceSummary>(); while (await reader.ReadAsync(ct)) result.Add(new(reader.GetGuid(0), reader.GetString(1), reader.GetDecimal(2), reader.GetInt32(3))); return result;
    }

    public async Task<AvailabilityResponse> CheckAvailabilityAsync(Guid groupId, Guid professionalUserId, DateTimeOffset startsAt, DateTimeOffset endsAt, CancellationToken ct)
    {
        if (endsAt <= startsAt) throw new ArgumentException("Intervalo de horário inválido.");
        var conflicts = await FindConflictsAsync(groupId, professionalUserId, startsAt, endsAt, ct); return new(conflicts.Count == 0, conflicts);
    }

    public async Task<AppointmentSummary> CreateAppointmentAsync(CreateAppointmentRequest request, CancellationToken ct)
    {
        if (request.DurationMinutes <= 0 || (request.ClientId is null && string.IsNullOrWhiteSpace(request.WalkInName))) throw new ArgumentException("Cliente e duração são obrigatórios.");
        var endsAt = request.StartsAt.AddMinutes(request.DurationMinutes);
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct); await using var transaction = await connection.BeginTransactionAsync(ct);
        await using (var lockCommand = new NpgsqlCommand("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", connection, transaction)) { lockCommand.Parameters.AddWithValue($"{request.GroupId:N}:{request.ProfessionalUserId:N}"); await lockCommand.ExecuteNonQueryAsync(ct); }
        var conflicts = await FindAppointmentsAsync(connection, transaction, request.GroupId, request.ProfessionalUserId, request.StartsAt, endsAt, true, ct);
        if (conflicts.Count > 0 && !request.ForceConflict) throw new InvalidOperationException("APPOINTMENT_CONFLICT");
        var isFitIn = request.IsFitIn || (conflicts.Count > 0 && request.ForceConflict);
        decimal price; int serviceDuration; string clientName;
        await using (var professionalCommand = new NpgsqlCommand("SELECT 1 FROM bck_user WHERE id=$1 AND group_id=$2 AND active=true AND serves_clients=true", connection, transaction)) { professionalCommand.Parameters.AddWithValue(request.ProfessionalUserId); professionalCommand.Parameters.AddWithValue(request.GroupId); if (await professionalCommand.ExecuteScalarAsync(ct) is null) throw new ArgumentException("Profissional não encontrado ou não habilitado para atender."); }
        await using (var creatorCommand = new NpgsqlCommand("SELECT 1 FROM bck_user WHERE id=$1 AND group_id=$2 AND active=true", connection, transaction)) { creatorCommand.Parameters.AddWithValue(request.CreatedByUserId); creatorCommand.Parameters.AddWithValue(request.GroupId); if (await creatorCommand.ExecuteScalarAsync(ct) is null) throw new ArgumentException("Usuário responsável não encontrado."); }
        await using (var serviceCommand = new NpgsqlCommand("SELECT standard_price,standard_duration_minutes FROM service WHERE id=$1 AND group_id=$2 AND active=true", connection, transaction)) { serviceCommand.Parameters.AddWithValue(request.ServiceId); serviceCommand.Parameters.AddWithValue(request.GroupId); await using var reader = await serviceCommand.ExecuteReaderAsync(ct); if (!await reader.ReadAsync(ct)) throw new ArgumentException("Serviço não encontrado."); price=reader.GetDecimal(0); serviceDuration=reader.GetInt32(1); }
        if (request.ClientId is not null) { await using var clientCommand = new NpgsqlCommand("SELECT name FROM client WHERE id=$1 AND group_id=$2 AND active=true", connection, transaction); clientCommand.Parameters.AddWithValue(request.ClientId.Value); clientCommand.Parameters.AddWithValue(request.GroupId); clientName=(string?)await clientCommand.ExecuteScalarAsync(ct) ?? throw new ArgumentException("Cliente não encontrado."); } else clientName=request.WalkInName!.Trim();
        Guid appointmentId;
        await using (var command = new NpgsqlCommand("INSERT INTO appointment(group_id,client_id,walk_in_name,walk_in_phone,professional_user_id,created_by_user_id,starts_at,ends_at,notes,is_fit_in) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id", connection, transaction)) { command.Parameters.AddWithValue(request.GroupId); command.Parameters.AddWithValue((object?)request.ClientId ?? DBNull.Value); command.Parameters.AddWithValue((object?)request.WalkInName ?? DBNull.Value); command.Parameters.AddWithValue((object?)request.WalkInPhone ?? DBNull.Value); command.Parameters.AddWithValue(request.ProfessionalUserId); command.Parameters.AddWithValue(request.CreatedByUserId); command.Parameters.AddWithValue(request.StartsAt); command.Parameters.AddWithValue(endsAt); command.Parameters.AddWithValue((object?)request.Notes ?? DBNull.Value); command.Parameters.AddWithValue(isFitIn); appointmentId=(Guid)(await command.ExecuteScalarAsync(ct))!; }
        await using (var item = new NpgsqlCommand("INSERT INTO appointment_service(appointment_id,service_id,price_snapshot,duration_minutes_snapshot) VALUES($1,$2,$3,$4)", connection, transaction)) { item.Parameters.AddWithValue(appointmentId); item.Parameters.AddWithValue(request.ServiceId); item.Parameters.AddWithValue(price); item.Parameters.AddWithValue(request.DurationMinutes == serviceDuration ? serviceDuration : request.DurationMinutes); await item.ExecuteNonQueryAsync(ct); }
        await using (var history = new NpgsqlCommand("INSERT INTO appointment_status_history(group_id,appointment_id,to_status,changed_by_user_id) VALUES($1,$2,'SCHEDULED',$3)", connection, transaction)) { history.Parameters.AddWithValue(request.GroupId); history.Parameters.AddWithValue(appointmentId); history.Parameters.AddWithValue(request.CreatedByUserId); await history.ExecuteNonQueryAsync(ct); }
        await transaction.CommitAsync(ct); return new(appointmentId, request.ProfessionalUserId, request.ClientId, clientName, request.StartsAt, endsAt, "SCHEDULED", isFitIn);
    }

    public async Task<RescheduleAppointmentResult?> RescheduleAsync(Guid groupId, Guid appointmentId, Guid changedByUserId, RescheduleAppointmentRequest request, CancellationToken ct)
    {
        if (request.DurationMinutes <= 0) throw new ArgumentException("Duração inválida.");
        var endsAt = request.StartsAt.AddMinutes(request.DurationMinutes);
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct); await using var transaction = await connection.BeginTransactionAsync(ct);
        await using (var lockCommand = new NpgsqlCommand("SELECT pg_advisory_xact_lock(hashtextextended($1,0))",connection,transaction)){lockCommand.Parameters.AddWithValue($"{groupId:N}:{request.ProfessionalUserId:N}");await lockCommand.ExecuteNonQueryAsync(ct);}
        Guid? clientId; string? walkInName; string? walkInPhone; string? notes; string currentStatus; string clientName; Guid serviceId; decimal price; int oldDuration;
        await using (var q=new NpgsqlCommand("SELECT a.client_id,a.walk_in_name,a.walk_in_phone,a.notes,a.status,COALESCE(c.name,a.walk_in_name,'Cliente'),aps.service_id,aps.price_snapshot,aps.duration_minutes_snapshot FROM appointment a LEFT JOIN client c ON c.id=a.client_id AND c.group_id=a.group_id JOIN appointment_service aps ON aps.appointment_id=a.id WHERE a.id=$1 AND a.group_id=$2 FOR UPDATE OF a",connection,transaction)){q.Parameters.AddWithValue(appointmentId);q.Parameters.AddWithValue(groupId);await using var r=await q.ExecuteReaderAsync(ct);if(!await r.ReadAsync(ct))return null;clientId=r.IsDBNull(0)?null:r.GetGuid(0);walkInName=r.IsDBNull(1)?null:r.GetString(1);walkInPhone=r.IsDBNull(2)?null:r.GetString(2);notes=r.IsDBNull(3)?null:r.GetString(3);currentStatus=r.GetString(4);clientName=r.GetString(5);serviceId=r.GetGuid(6);price=r.GetDecimal(7);oldDuration=r.GetInt32(8);}
        if(!AllowedTransitions.TryGetValue(currentStatus,out var allowed)||!allowed.Contains("RESCHEDULED"))throw new InvalidOperationException("INVALID_STATUS_TRANSITION");
        await using(var p=new NpgsqlCommand("SELECT 1 FROM bck_user WHERE id=$1 AND group_id=$2 AND active=true AND serves_clients=true",connection,transaction)){p.Parameters.AddWithValue(request.ProfessionalUserId);p.Parameters.AddWithValue(groupId);if(await p.ExecuteScalarAsync(ct)is null)throw new ArgumentException("Profissional não encontrado ou não habilitado para atender.");}
        var conflicts=await FindAppointmentsAsync(connection,transaction,groupId,request.ProfessionalUserId,request.StartsAt,endsAt,true,ct);conflicts.RemoveAll(x=>x.Id==appointmentId);if(conflicts.Count>0&&!request.ForceConflict)throw new InvalidOperationException("APPOINTMENT_CONFLICT");var isFitIn=conflicts.Count>0&&request.ForceConflict;
        Guid newId;await using(var q=new NpgsqlCommand("INSERT INTO appointment(group_id,client_id,walk_in_name,walk_in_phone,professional_user_id,created_by_user_id,starts_at,ends_at,notes,is_fit_in,rescheduled_from_appointment_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id",connection,transaction)){q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue((object?)clientId??DBNull.Value);q.Parameters.AddWithValue((object?)walkInName??DBNull.Value);q.Parameters.AddWithValue((object?)walkInPhone??DBNull.Value);q.Parameters.AddWithValue(request.ProfessionalUserId);q.Parameters.AddWithValue(changedByUserId);q.Parameters.AddWithValue(request.StartsAt);q.Parameters.AddWithValue(endsAt);q.Parameters.AddWithValue((object?)notes??DBNull.Value);q.Parameters.AddWithValue(isFitIn);q.Parameters.AddWithValue(appointmentId);newId=(Guid)(await q.ExecuteScalarAsync(ct))!;}
        await using(var q=new NpgsqlCommand("INSERT INTO appointment_service(appointment_id,service_id,price_snapshot,duration_minutes_snapshot) VALUES($1,$2,$3,$4)",connection,transaction)){q.Parameters.AddWithValue(newId);q.Parameters.AddWithValue(serviceId);q.Parameters.AddWithValue(price);q.Parameters.AddWithValue(request.DurationMinutes>0?request.DurationMinutes:oldDuration);await q.ExecuteNonQueryAsync(ct);}
        await using(var q=new NpgsqlCommand("UPDATE appointment SET status='RESCHEDULED',rescheduled_to_appointment_id=$1,updated_at=now() WHERE id=$2 AND group_id=$3",connection,transaction)){q.Parameters.AddWithValue(newId);q.Parameters.AddWithValue(appointmentId);q.Parameters.AddWithValue(groupId);await q.ExecuteNonQueryAsync(ct);}
        await using(var h=new NpgsqlCommand("INSERT INTO appointment_status_history(group_id,appointment_id,from_status,to_status,changed_by_user_id,reason) VALUES($1,$2,$3,'RESCHEDULED',$4,$5),($1,$6,NULL,'SCHEDULED',$4,$7)",connection,transaction)){h.Parameters.AddWithValue(groupId);h.Parameters.AddWithValue(appointmentId);h.Parameters.AddWithValue(currentStatus);h.Parameters.AddWithValue(changedByUserId);h.Parameters.AddWithValue((object?)request.Reason?.Trim()??DBNull.Value);h.Parameters.AddWithValue(newId);h.Parameters.AddWithValue($"Remarcado a partir do agendamento {appointmentId}");await h.ExecuteNonQueryAsync(ct);}
        await transaction.CommitAsync(ct);return new(appointmentId,new(newId,request.ProfessionalUserId,clientId,clientName,request.StartsAt,endsAt,"SCHEDULED",isFitIn));
    }

    public async Task<string> ChangeStatusAsync(Guid groupId, Guid appointmentId, Guid changedByUserId, string status, string? reason, CancellationToken ct)
    {
        var target = status.Trim().ToUpperInvariant(); if (!AppointmentStatuses.Contains(target)) throw new ArgumentException("Status de agendamento inválido.");
        await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct); await using var transaction = await connection.BeginTransactionAsync(ct);
        string? current; await using (var q = new NpgsqlCommand("SELECT status FROM appointment WHERE id=$1 AND group_id=$2 FOR UPDATE", connection, transaction)) { q.Parameters.AddWithValue(appointmentId); q.Parameters.AddWithValue(groupId); current = (string?)await q.ExecuteScalarAsync(ct); }
        if (current is null) return "NOT_FOUND"; if (string.Equals(current,target,StringComparison.OrdinalIgnoreCase)) return "UNCHANGED";
        if (!AllowedTransitions.TryGetValue(current,out var allowed) || !allowed.Contains(target)) throw new InvalidOperationException("INVALID_STATUS_TRANSITION");
        await using (var q = new NpgsqlCommand("UPDATE appointment SET status=$1,updated_at=now() WHERE id=$2 AND group_id=$3", connection, transaction)) { q.Parameters.AddWithValue(target); q.Parameters.AddWithValue(appointmentId); q.Parameters.AddWithValue(groupId); await q.ExecuteNonQueryAsync(ct); }
        await using (var h = new NpgsqlCommand("INSERT INTO appointment_status_history(group_id,appointment_id,from_status,to_status,changed_by_user_id,reason) VALUES($1,$2,$3,$4,$5,$6)", connection, transaction)) { h.Parameters.AddWithValue(groupId); h.Parameters.AddWithValue(appointmentId); h.Parameters.AddWithValue(current); h.Parameters.AddWithValue(target); h.Parameters.AddWithValue(changedByUserId); h.Parameters.AddWithValue((object?)reason?.Trim() ?? DBNull.Value); await h.ExecuteNonQueryAsync(ct); }
        await transaction.CommitAsync(ct); return "UPDATED";
    }

    public async Task<IReadOnlyList<AppointmentSummary>> ListAppointmentsAsync(Guid groupId, Guid professionalUserId, DateTimeOffset from, DateTimeOffset to, CancellationToken ct) => await FindAppointmentsAsync(groupId, professionalUserId, from, to, false, ct);
    private async Task<List<AppointmentSummary>> FindConflictsAsync(Guid groupId, Guid professionalUserId, DateTimeOffset startsAt, DateTimeOffset endsAt, CancellationToken ct) => await FindAppointmentsAsync(groupId, professionalUserId, startsAt, endsAt, true, ct);
    private async Task<List<AppointmentSummary>> FindAppointmentsAsync(Guid groupId, Guid professionalUserId, DateTimeOffset from, DateTimeOffset to, bool overlap, CancellationToken ct) { await using var connection = new NpgsqlConnection(ConnectionString); await connection.OpenAsync(ct); return await FindAppointmentsAsync(connection, null, groupId, professionalUserId, from, to, overlap, ct); }
    private static async Task<List<AppointmentSummary>> FindAppointmentsAsync(NpgsqlConnection connection, NpgsqlTransaction? transaction, Guid groupId, Guid professionalUserId, DateTimeOffset from, DateTimeOffset to, bool overlap, CancellationToken ct)
    {
        var timeClause = overlap ? "a.starts_at < $4 AND a.ends_at > $3" : "a.starts_at >= $3 AND a.starts_at < $4";
        var sql = $"SELECT a.id,a.professional_user_id,a.client_id,COALESCE(c.name,a.walk_in_name,'Cliente'),a.starts_at,a.ends_at,a.status,a.is_fit_in FROM appointment a LEFT JOIN client c ON c.id=a.client_id AND c.group_id=a.group_id WHERE a.group_id=$1 AND a.professional_user_id=$2 AND a.status NOT IN ('CANCELLED','RESCHEDULED') AND {timeClause} ORDER BY a.starts_at";
        await using var command = new NpgsqlCommand(sql, connection, transaction); command.Parameters.AddWithValue(groupId); command.Parameters.AddWithValue(professionalUserId); command.Parameters.AddWithValue(from); command.Parameters.AddWithValue(to);
        await using var reader = await command.ExecuteReaderAsync(ct); var result = new List<AppointmentSummary>(); while(await reader.ReadAsync(ct)) result.Add(new(reader.GetGuid(0),reader.GetGuid(1),reader.IsDBNull(2)?null:reader.GetGuid(2),reader.GetString(3),reader.GetFieldValue<DateTimeOffset>(4),reader.GetFieldValue<DateTimeOffset>(5),reader.GetString(6),reader.GetBoolean(7))); return result;
    }
}
