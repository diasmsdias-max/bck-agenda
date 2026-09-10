using System.Security.Claims;
using Bck.Api.Features.Agenda;
using Bck.Api.Features.Auth;
using Bck.Api.Features.Bootstrap;
using Bck.Api.Infrastructure.Database;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHealthChecks();
builder.Services.AddOpenApi();
builder.Services.AddSingleton<PostgresProbe>();
builder.Services.AddScoped<BootstrapService>();
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<AgendaService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = JwtTokenService.Issuer,
        ValidateAudience = true,
        ValidAudience = JwtTokenService.Audience,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(JwtTokenService.GetSigningKey(builder.Configuration)),
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromSeconds(30),
    };
});
builder.Services.AddAuthorization();

var app = builder.Build();
if (app.Environment.IsDevelopment()) app.MapOpenApi();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/v1/health", () => Results.Ok(new { status = "ok", service = "BCK Agenda API", version = "0.4.0", serverTimeUtc = DateTimeOffset.UtcNow }));
app.MapGet("/api/v1/health/database", async (PostgresProbe probe, CancellationToken ct) => { var result = await probe.CheckAsync(ct); return result.Ready ? Results.Ok(new { status = "ok", database = result.Database, foundationMigration = "applied" }) : Results.Json(new { status = "unavailable", code = "DATABASE_UNAVAILABLE" }, statusCode: 503); });
app.MapGet("/api/v1/system/time", () => Results.Ok(new { serverTimeUtc = DateTimeOffset.UtcNow }));

app.MapPost("/api/v1/bootstrap/company", async (CreateCompanyRequest request, BootstrapService service, CancellationToken ct) => { try { var result = await service.CreateCompanyAsync(request, ct); return Results.Created($"/api/v1/groups/{result.GroupId}", result); } catch (ArgumentException ex) { return Results.BadRequest(new { code = "VALIDATION_ERROR", message = ex.Message }); } });
app.MapPost("/api/v1/auth/login", async (LoginRequest request, AuthService service, CancellationToken ct) => { var result = await service.LoginAsync(request, ct); return result is null ? Results.Json(new { code = "INVALID_CREDENTIALS", message = "Credenciais ou dispositivo inválidos." }, statusCode: 401) : Results.Ok(result); });
app.MapPost("/api/v1/auth/refresh", async (RefreshRequest request, AuthService service, CancellationToken ct) => { var result = await service.RefreshAsync(request, ct); return result is null ? Results.Json(new { code = "INVALID_REFRESH_TOKEN", message = "Sessão expirada, revogada ou inválida." }, statusCode: 401) : Results.Ok(result); });
app.MapPost("/api/v1/auth/logout", async (LogoutRequest request, AuthService service, CancellationToken ct) => { await service.LogoutAsync(request, ct); return Results.NoContent(); });
app.MapGet("/api/v1/auth/me", (ClaimsPrincipal user) => Results.Ok(new
{
    userId = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub"),
    groupId = user.FindFirstValue("group_id"),
    deviceId = user.FindFirstValue("device_id"),
    profile = user.FindFirstValue("profile"),
    isOwner = string.Equals(user.FindFirstValue("is_owner"), "true", StringComparison.OrdinalIgnoreCase),
    permissionVersion = user.FindFirstValue("permission_version"),
    securityVersion = user.FindFirstValue("security_version"),
})).RequireAuthorization();

var protectedApi = app.MapGroup("/api/v1").RequireAuthorization();
protectedApi.MapPost("/clients", async (CreateClientRequest request, ClaimsPrincipal user, AgendaService service, CancellationToken ct) => { try { var secured = request with { GroupId = GroupId(user), CreatedByUserId = UserId(user) }; var result=await service.CreateClientAsync(secured,ct); return Results.Created($"/api/v1/clients/{result.Id}",result); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
protectedApi.MapGet("/clients", async (string? q, ClaimsPrincipal user, AgendaService service, CancellationToken ct) => Results.Ok(await service.SearchClientsAsync(GroupId(user),q,ct)));
protectedApi.MapPost("/services", async (CreateServiceRequest request, ClaimsPrincipal user, AgendaService service, CancellationToken ct) => { try { var secured = request with { GroupId = GroupId(user) }; var result=await service.CreateServiceAsync(secured,ct); return Results.Created($"/api/v1/services/{result.Id}",result); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
protectedApi.MapGet("/services", async (ClaimsPrincipal user, AgendaService service, CancellationToken ct) => Results.Ok(await service.ListServicesAsync(GroupId(user),ct)));
protectedApi.MapGet("/appointments/availability", async (Guid professionalUserId, DateTimeOffset startsAt, DateTimeOffset endsAt, ClaimsPrincipal user, AgendaService service, CancellationToken ct) => { try { return Results.Ok(await service.CheckAvailabilityAsync(GroupId(user),professionalUserId,startsAt,endsAt,ct)); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
protectedApi.MapPost("/appointments", async (CreateAppointmentRequest request, ClaimsPrincipal user, AgendaService service, CancellationToken ct) => { try { var secured = request with { GroupId = GroupId(user), CreatedByUserId = UserId(user) }; var result=await service.CreateAppointmentAsync(secured,ct); return Results.Created($"/api/v1/appointments/{result.Id}",result); } catch(InvalidOperationException ex) when(ex.Message=="APPOINTMENT_CONFLICT") { return Results.Conflict(new { code="APPOINTMENT_CONFLICT",message="Já existe atendimento do profissional nesse intervalo." }); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
protectedApi.MapGet("/appointments", async (Guid professionalUserId, DateTimeOffset from, DateTimeOffset to, ClaimsPrincipal user, AgendaService service, CancellationToken ct) => Results.Ok(await service.ListAppointmentsAsync(GroupId(user),professionalUserId,from,to,ct)));

app.MapHealthChecks("/health");
app.Run();

static Guid GroupId(ClaimsPrincipal user) => Guid.Parse(user.FindFirstValue("group_id") ?? throw new UnauthorizedAccessException("Missing group claim."));
static Guid UserId(ClaimsPrincipal user) => Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub") ?? throw new UnauthorizedAccessException("Missing user claim."));
public partial class Program { }
