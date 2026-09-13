using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

namespace Bck.Api.Features.ServiceSessions;

public sealed record ServiceSessionIdempotencyReplay(int StatusCode, string ResponseJson);

public static class ServiceSessionIdempotency
{
    public const string HeaderName = "Idempotency-Key";

    public static string RequireKey(HttpRequest request)
    {
        if (!request.Headers.TryGetValue(HeaderName, out var values)) throw new ArgumentException("IDEMPOTENCY_KEY_REQUIRED");
        var key = values.ToString().Trim();
        if (key.Length is < 8 or > 128) throw new ArgumentException("IDEMPOTENCY_KEY_INVALID");
        return key;
    }

    public static string RequestHash<T>(T request)
    {
        var json = JsonSerializer.Serialize(request);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))).ToLowerInvariant();
    }

    public static async Task<ServiceSessionIdempotencyReplay?> BeginAsync(NpgsqlConnection connection,NpgsqlTransaction transaction,Guid groupId,Guid userId,string operation,string key,string requestHash,CancellationToken ct)
    {
        const string insertSql="INSERT INTO service_session_idempotency(group_id,user_id,operation,idempotency_key,request_hash) VALUES($1,$2,$3,$4,$5) ON CONFLICT (group_id,user_id,operation,idempotency_key) DO NOTHING";
        await using(var insert=new NpgsqlCommand(insertSql,connection,transaction)){insert.Parameters.AddWithValue(groupId);insert.Parameters.AddWithValue(userId);insert.Parameters.AddWithValue(operation);insert.Parameters.AddWithValue(key);insert.Parameters.AddWithValue(requestHash);if(await insert.ExecuteNonQueryAsync(ct)==1)return null;}
        const string readSql="SELECT request_hash,status_code,response_json::text FROM service_session_idempotency WHERE group_id=$1 AND user_id=$2 AND operation=$3 AND idempotency_key=$4 FOR UPDATE";
        await using var read=new NpgsqlCommand(readSql,connection,transaction);read.Parameters.AddWithValue(groupId);read.Parameters.AddWithValue(userId);read.Parameters.AddWithValue(operation);read.Parameters.AddWithValue(key);await using var reader=await read.ExecuteReaderAsync(ct);if(!await reader.ReadAsync(ct))throw new InvalidOperationException("IDEMPOTENCY_STATE_MISSING");if(!string.Equals(reader.GetString(0),requestHash,StringComparison.Ordinal))throw new InvalidOperationException("IDEMPOTENCY_KEY_REUSED");if(reader.IsDBNull(1)||reader.IsDBNull(2))throw new InvalidOperationException("IDEMPOTENCY_REQUEST_IN_PROGRESS");return new(reader.GetInt32(1),reader.GetString(2));
    }

    public static async Task CompleteAsync<T>(NpgsqlConnection connection,NpgsqlTransaction transaction,Guid groupId,Guid userId,string operation,string key,int statusCode,T response,CancellationToken ct)
    {
        var json=JsonSerializer.Serialize(response);const string sql="UPDATE service_session_idempotency SET status_code=$1,response_json=CAST($2 AS jsonb),completed_at=now() WHERE group_id=$3 AND user_id=$4 AND operation=$5 AND idempotency_key=$6 AND completed_at IS NULL";await using var command=new NpgsqlCommand(sql,connection,transaction);command.Parameters.AddWithValue(statusCode);command.Parameters.AddWithValue(json);command.Parameters.AddWithValue(groupId);command.Parameters.AddWithValue(userId);command.Parameters.AddWithValue(operation);command.Parameters.AddWithValue(key);if(await command.ExecuteNonQueryAsync(ct)!=1)throw new InvalidOperationException("IDEMPOTENCY_STATE_INVALID");
    }

    public static T Deserialize<T>(ServiceSessionIdempotencyReplay replay)=>JsonSerializer.Deserialize<T>(replay.ResponseJson,new JsonSerializerOptions(JsonSerializerDefaults.Web))??throw new InvalidOperationException("IDEMPOTENCY_RESPONSE_INVALID");
}
