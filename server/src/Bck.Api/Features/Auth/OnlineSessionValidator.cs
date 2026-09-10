using System.Security.Claims;
using Npgsql;

namespace Bck.Api.Features.Auth;

public sealed class OnlineSessionValidator(IConfiguration configuration)
{
    public async Task<bool> IsCurrentAsync(ClaimsPrincipal principal,CancellationToken ct)
    {
        if(!Guid.TryParse(principal.FindFirstValue("group_id"),out var groupId)||
           !Guid.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier)??principal.FindFirstValue("sub"),out var userId)||
           !Guid.TryParse(principal.FindFirstValue("device_id"),out var deviceId)||
           !int.TryParse(principal.FindFirstValue("permission_version"),out var permissionVersion)||
           !int.TryParse(principal.FindFirstValue("security_version"),out var securityVersion)) return false;

        var cs=configuration.GetConnectionString("Postgres")??Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")??throw new InvalidOperationException("PostgreSQL connection is not configured.");
        await using var c=new NpgsqlConnection(cs); await c.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("SELECT EXISTS(SELECT 1 FROM bck_user u JOIN device_user du ON du.user_id=u.id JOIN device d ON d.id=du.device_id AND d.group_id=u.group_id WHERE u.id=$1 AND u.group_id=$2 AND u.active=true AND u.permission_version=$3 AND d.id=$4 AND d.status='ACTIVE' AND d.revoked_at IS NULL AND d.security_version=$5)",c);
        cmd.Parameters.AddWithValue(userId); cmd.Parameters.AddWithValue(groupId); cmd.Parameters.AddWithValue(permissionVersion); cmd.Parameters.AddWithValue(deviceId); cmd.Parameters.AddWithValue(securityVersion);
        return (bool)(await cmd.ExecuteScalarAsync(ct))!;
    }
}
