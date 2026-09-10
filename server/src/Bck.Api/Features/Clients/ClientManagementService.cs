using Npgsql;

namespace Bck.Api.Features.Clients;

public sealed record ClientListItem(Guid Id,string Name,string Phone,bool WhatsAppEnabled,string? Notes,DateOnly? BirthDate,bool Active,int Version,DateTimeOffset CreatedAt,DateTimeOffset UpdatedAt);
public sealed record ClientDetail(Guid Id,string Name,string Phone,bool WhatsAppEnabled,string? Notes,DateOnly? BirthDate,bool Active,int Version,Guid? CreatedByUserId,DateTimeOffset CreatedAt,DateTimeOffset UpdatedAt);
public sealed record CreateManagedClientRequest(string Name,string Phone,bool WhatsAppEnabled=true,string? Notes=null,DateOnly? BirthDate=null);
public sealed record UpdateManagedClientRequest(string Name,string Phone,bool WhatsAppEnabled,string? Notes,DateOnly? BirthDate,int Version);
public sealed record ClientDuplicate(Guid Id,string Name,string Phone,bool Active);
public sealed record ClientHistoryItem(Guid AppointmentId,DateTimeOffset StartsAt,DateTimeOffset EndsAt,string Status,Guid ProfessionalUserId,string ProfessionalName,Guid? ServiceId,string? ServiceName,decimal? ServicePrice);

public sealed class ClientManagementService(IConfiguration configuration)
{
    string Cs()=>configuration.GetConnectionString("Postgres")??Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")??throw new InvalidOperationException("PostgreSQL connection is not configured.");

    public async Task<IReadOnlyList<ClientListItem>> ListAsync(Guid groupId,string? query,bool includeInactive,CancellationToken ct)
    {
        await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);
        const string sql="SELECT id,name,phone,whatsapp_enabled,notes,birth_date,active,version,created_at,updated_at FROM client WHERE group_id=$1 AND ($2 OR active=true) AND ($3='' OR name ILIKE '%'||$3||'%' OR phone ILIKE '%'||$3||'%') ORDER BY active DESC,name LIMIT 100";
        await using var q=new NpgsqlCommand(sql,c);q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue(includeInactive);q.Parameters.AddWithValue(query?.Trim()??"");
        await using var r=await q.ExecuteReaderAsync(ct);var result=new List<ClientListItem>();while(await r.ReadAsync(ct))result.Add(new(r.GetGuid(0),r.GetString(1),r.GetString(2),r.GetBoolean(3),r.IsDBNull(4)?null:r.GetString(4),r.IsDBNull(5)?null:r.GetFieldValue<DateOnly>(5),r.GetBoolean(6),r.GetInt32(7),r.GetFieldValue<DateTimeOffset>(8),r.GetFieldValue<DateTimeOffset>(9)));return result;
    }

    public async Task<ClientDetail?> GetAsync(Guid groupId,Guid id,CancellationToken ct)
    {
        await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var q=new NpgsqlCommand("SELECT id,name,phone,whatsapp_enabled,notes,birth_date,active,version,created_by_user_id,created_at,updated_at FROM client WHERE id=$1 AND group_id=$2",c);q.Parameters.AddWithValue(id);q.Parameters.AddWithValue(groupId);await using var r=await q.ExecuteReaderAsync(ct);if(!await r.ReadAsync(ct))return null;return new(r.GetGuid(0),r.GetString(1),r.GetString(2),r.GetBoolean(3),r.IsDBNull(4)?null:r.GetString(4),r.IsDBNull(5)?null:r.GetFieldValue<DateOnly>(5),r.GetBoolean(6),r.GetInt32(7),r.IsDBNull(8)?null:r.GetGuid(8),r.GetFieldValue<DateTimeOffset>(9),r.GetFieldValue<DateTimeOffset>(10));
    }

    public async Task<IReadOnlyList<ClientHistoryItem>?> HistoryAsync(Guid groupId,Guid id,CancellationToken ct)
    {
        if(!await Exists(groupId,id,ct))return null;
        await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);
        const string sql="SELECT a.id,a.starts_at,a.ends_at,a.status,a.professional_user_id,u.name,aps.service_id,s.name,aps.price_snapshot FROM appointment a JOIN bck_user u ON u.id=a.professional_user_id AND u.group_id=a.group_id LEFT JOIN appointment_service aps ON aps.appointment_id=a.id LEFT JOIN service s ON s.id=aps.service_id AND s.group_id=a.group_id WHERE a.group_id=$1 AND a.client_id=$2 ORDER BY a.starts_at DESC,a.created_at DESC";
        await using var q=new NpgsqlCommand(sql,c);q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue(id);await using var r=await q.ExecuteReaderAsync(ct);var result=new List<ClientHistoryItem>();while(await r.ReadAsync(ct))result.Add(new(r.GetGuid(0),r.GetFieldValue<DateTimeOffset>(1),r.GetFieldValue<DateTimeOffset>(2),r.GetString(3),r.GetGuid(4),r.GetString(5),r.IsDBNull(6)?null:r.GetGuid(6),r.IsDBNull(7)?null:r.GetString(7),r.IsDBNull(8)?null:r.GetDecimal(8)));return result;
    }

    public async Task<IReadOnlyList<ClientDuplicate>> FindDuplicatesAsync(Guid groupId,string phone,Guid? excludeId,CancellationToken ct)
    {
        var normalized=NormalizePhone(phone);if(normalized.Length<8)return [];
        await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var q=new NpgsqlCommand("SELECT id,name,phone,active FROM client WHERE group_id=$1 AND regexp_replace(phone,'[^0-9]','','g')=$2 AND ($3::uuid IS NULL OR id<>$3) ORDER BY active DESC,name",c);q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue(normalized);q.Parameters.AddWithValue((object?)excludeId??DBNull.Value);await using var r=await q.ExecuteReaderAsync(ct);var result=new List<ClientDuplicate>();while(await r.ReadAsync(ct))result.Add(new(r.GetGuid(0),r.GetString(1),r.GetString(2),r.GetBoolean(3)));return result;
    }

    public async Task<ClientDetail> CreateAsync(Guid groupId,Guid actor,CreateManagedClientRequest request,CancellationToken ct)
    {
        Validate(request.Name,request.Phone);await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var t=await c.BeginTransactionAsync(ct);var id=Guid.NewGuid();await using(var q=new NpgsqlCommand("INSERT INTO client(id,group_id,name,phone,whatsapp_enabled,notes,birth_date,created_by_user_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",c,t)){q.Parameters.AddWithValue(id);q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue(request.Name.Trim());q.Parameters.AddWithValue(request.Phone.Trim());q.Parameters.AddWithValue(request.WhatsAppEnabled);q.Parameters.AddWithValue((object?)Clean(request.Notes)??DBNull.Value);q.Parameters.AddWithValue((object?)request.BirthDate??DBNull.Value);q.Parameters.AddWithValue(actor);await q.ExecuteNonQueryAsync(ct);}await Audit(c,t,groupId,actor,id,"CLIENT_CREATED",ct);await t.CommitAsync(ct);return(await GetAsync(groupId,id,ct))!;
    }

    public async Task<string> UpdateAsync(Guid groupId,Guid actor,Guid id,UpdateManagedClientRequest request,CancellationToken ct)
    {
        Validate(request.Name,request.Phone);if(request.Version<1)throw new ArgumentException("Versão do cliente inválida.");await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var t=await c.BeginTransactionAsync(ct);await using var q=new NpgsqlCommand("UPDATE client SET name=$4,phone=$5,whatsapp_enabled=$6,notes=$7,birth_date=$8,version=version+1,updated_at=now() WHERE id=$1 AND group_id=$2 AND version=$3",c,t);q.Parameters.AddWithValue(id);q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue(request.Version);q.Parameters.AddWithValue(request.Name.Trim());q.Parameters.AddWithValue(request.Phone.Trim());q.Parameters.AddWithValue(request.WhatsAppEnabled);q.Parameters.AddWithValue((object?)Clean(request.Notes)??DBNull.Value);q.Parameters.AddWithValue((object?)request.BirthDate??DBNull.Value);if(await q.ExecuteNonQueryAsync(ct)==1){await Audit(c,t,groupId,actor,id,"CLIENT_UPDATED",ct);await t.CommitAsync(ct);return "UPDATED";}await t.RollbackAsync(ct);return await Exists(groupId,id,ct)?"CONFLICT":"NOT_FOUND";
    }

    public async Task<bool> ReactivateAsync(Guid groupId,Guid actor,Guid id,CancellationToken ct)
    {
        await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var t=await c.BeginTransactionAsync(ct);await using var q=new NpgsqlCommand("UPDATE client SET active=true,version=version+1,updated_at=now() WHERE id=$1 AND group_id=$2 AND active=false",c,t);q.Parameters.AddWithValue(id);q.Parameters.AddWithValue(groupId);if(await q.ExecuteNonQueryAsync(ct)!=1){await t.RollbackAsync(ct);return false;}await Audit(c,t,groupId,actor,id,"CLIENT_REACTIVATED",ct);await t.CommitAsync(ct);return true;
    }

    public async Task<string> RemoveAsync(Guid groupId,Guid actor,Guid id,CancellationToken ct)
    {
        await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var t=await c.BeginTransactionAsync(ct);await using(var check=new NpgsqlCommand("SELECT EXISTS(SELECT 1 FROM appointment WHERE group_id=$1 AND client_id=$2)",c,t)){check.Parameters.AddWithValue(groupId);check.Parameters.AddWithValue(id);var hasHistory=(bool)(await check.ExecuteScalarAsync(ct))!;if(hasHistory){await using var q=new NpgsqlCommand("UPDATE client SET active=false,version=version+1,updated_at=now() WHERE id=$1 AND group_id=$2 AND active=true",c,t);q.Parameters.AddWithValue(id);q.Parameters.AddWithValue(groupId);if(await q.ExecuteNonQueryAsync(ct)!=1){await t.RollbackAsync(ct);return "NOT_FOUND";}await Audit(c,t,groupId,actor,id,"CLIENT_INACTIVATED",ct);await t.CommitAsync(ct);return "INACTIVATED";}}
        await using(var d=new NpgsqlCommand("DELETE FROM client WHERE id=$1 AND group_id=$2",c,t)){d.Parameters.AddWithValue(id);d.Parameters.AddWithValue(groupId);if(await d.ExecuteNonQueryAsync(ct)!=1){await t.RollbackAsync(ct);return "NOT_FOUND";}}await Audit(c,t,groupId,actor,id,"CLIENT_DELETED",ct);await t.CommitAsync(ct);return "DELETED";
    }

    async Task<bool> Exists(Guid groupId,Guid id,CancellationToken ct){await using var c=new NpgsqlConnection(Cs());await c.OpenAsync(ct);await using var q=new NpgsqlCommand("SELECT EXISTS(SELECT 1 FROM client WHERE id=$1 AND group_id=$2)",c);q.Parameters.AddWithValue(id);q.Parameters.AddWithValue(groupId);return(bool)(await q.ExecuteScalarAsync(ct))!;}
    static void Validate(string name,string phone){if(string.IsNullOrWhiteSpace(name)||string.IsNullOrWhiteSpace(phone))throw new ArgumentException("Nome e telefone são obrigatórios.");if(NormalizePhone(phone).Length<8)throw new ArgumentException("Telefone inválido.");}
    static string NormalizePhone(string phone)=>new(phone.Where(char.IsDigit).ToArray());
    static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    static async Task Audit(NpgsqlConnection c,NpgsqlTransaction t,Guid groupId,Guid actor,Guid id,string action,CancellationToken ct){await using var q=new NpgsqlCommand("INSERT INTO audit_log(group_id,user_id,action,entity_type,entity_id) VALUES($1,$2,$3,'CLIENT',$4)",c,t);q.Parameters.AddWithValue(groupId);q.Parameters.AddWithValue(actor);q.Parameters.AddWithValue(action);q.Parameters.AddWithValue(id);await q.ExecuteNonQueryAsync(ct);}
}
