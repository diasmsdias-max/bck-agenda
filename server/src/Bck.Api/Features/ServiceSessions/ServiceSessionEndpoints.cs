using System.Security.Claims;
using Npgsql;

namespace Bck.Api.Features.ServiceSessions;

public static class ServiceSessionEndpoints
{
    public static RouteGroupBuilder MapServiceSessionEndpoints(this RouteGroupBuilder api)
    {
        api.MapPost("/service-sessions", OpenAsync);
        api.MapGet("/service-sessions/{id:guid}", GetAsync);
        api.MapPost("/service-sessions/{id:guid}/items", AddItemAsync);
        api.MapPost("/service-sessions/{id:guid}/finish", FinishAsync);
        return api;
    }

    private static async Task<IResult> OpenAsync(OpenServiceSessionRequest request, ClaimsPrincipal user, ServiceSessionService service, CancellationToken ct)
    {
        try
        {
            var result = await service.OpenAsync(GroupId(user), UserId(user), request, ct);
            if (!IsAdmin(user) && result.ProfessionalUserId != UserId(user)) return Results.Forbid();
            return Results.Created($"/api/v1/service-sessions/{result.Id}", result);
        }
        catch (KeyNotFoundException) { return Results.NotFound(); }
        catch (UnauthorizedAccessException) { return Results.Forbid(); }
        catch (InvalidOperationException ex) when (ex.Message == "SERVICE_SESSION_ALREADY_EXISTS")
        { return Results.Conflict(new { code = ex.Message, message = "Este agendamento já possui atendimento aberto." }); }
        catch (InvalidOperationException ex) when (ex.Message == "APPOINTMENT_NOT_OPENABLE")
        { return Results.Conflict(new { code = ex.Message, message = "O estado atual do agendamento não permite abrir atendimento." }); }
    }

    private static async Task<IResult> GetAsync(Guid id, ClaimsPrincipal user, ServiceSessionService service, CancellationToken ct)
    {
        var result = await service.GetAsync(GroupId(user), id, ct);
        if (result is null) return Results.NotFound();
        if (!CanAccess(user, result.ProfessionalUserId)) return Results.Forbid();
        return Results.Ok(result);
    }

    private static async Task<IResult> AddItemAsync(Guid id, AddServiceSessionItemRequest request, ClaimsPrincipal user, ServiceSessionService service, IConfiguration configuration, CancellationToken ct)
    {
        var current = await service.GetAsync(GroupId(user), id, ct);
        if (current is null) return Results.NotFound();
        if (!CanAccess(user, current.ProfessionalUserId)) return Results.Forbid();
        var canDiscount = await CanDiscountAsync(user, configuration, ct);
        try { return Results.Created($"/api/v1/service-sessions/{id}/items", await service.AddItemAsync(GroupId(user), id, UserId(user), request, canDiscount, ct)); }
        catch (UnauthorizedAccessException ex) when (ex.Message == "DISCOUNT_NOT_ALLOWED") { return Results.Forbid(); }
        catch (InvalidOperationException ex) when (ex.Message == "SERVICE_SESSION_CLOSED") { return Results.Conflict(new { code = ex.Message, message = "O atendimento já está encerrado." }); }
        catch (ArgumentException ex) { return Results.BadRequest(new { code = "VALIDATION_ERROR", message = ex.Message }); }
    }

    private static async Task<IResult> FinishAsync(Guid id, FinishServiceSessionRequest request, ClaimsPrincipal user, ServiceSessionService service, CancellationToken ct)
    {
        var current = await service.GetAsync(GroupId(user), id, ct);
        if (current is null) return Results.NotFound();
        if (!CanAccess(user, current.ProfessionalUserId)) return Results.Forbid();
        try { return Results.Ok(await service.FinishAsync(GroupId(user), id, UserId(user), request, ct)); }
        catch (InvalidOperationException ex) when (ex.Message is "SERVICE_SESSION_CLOSED" or "APPOINTMENT_MUST_BE_IN_SERVICE")
        { return Results.Conflict(new { code = ex.Message, message = "O atendimento não pode ser finalizado no estado atual." }); }
    }

    private static bool CanAccess(ClaimsPrincipal user, Guid professionalId) => IsAdmin(user) || UserId(user) == professionalId;
    private static bool IsAdmin(ClaimsPrincipal user) => string.Equals(user.FindFirstValue("profile"), "ADMIN", StringComparison.OrdinalIgnoreCase);
    private static Guid GroupId(ClaimsPrincipal user) => Guid.Parse(user.FindFirstValue("group_id") ?? throw new UnauthorizedAccessException());
    private static Guid UserId(ClaimsPrincipal user) => Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

    private static async Task<bool> CanDiscountAsync(ClaimsPrincipal user, IConfiguration configuration, CancellationToken ct)
    {
        if (IsAdmin(user)) return true;
        var connectionString = configuration.GetConnectionString("Postgres") ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION") ?? throw new InvalidOperationException("PostgreSQL connection is not configured.");
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct);
        const string sql = "SELECT EXISTS(SELECT 1 FROM user_permission up JOIN permission p ON p.id=up.permission_id JOIN bck_user bu ON bu.id=up.user_id WHERE up.user_id=$1 AND bu.group_id=$2 AND bu.active=true AND up.granted=true AND p.code='ALLOW_PRICE_CHANGE')";
        await using var command = new NpgsqlCommand(sql, connection); command.Parameters.AddWithValue(UserId(user)); command.Parameters.AddWithValue(GroupId(user));
        return (bool)(await command.ExecuteScalarAsync(ct))!;
    }
}
