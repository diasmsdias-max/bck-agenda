using Bck.Api.Features.Auth;
using Bck.Api.Features.Bootstrap;
using Bck.Api.Infrastructure.Database;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHealthChecks();
builder.Services.AddOpenApi();
builder.Services.AddSingleton<PostgresProbe>();
builder.Services.AddScoped<BootstrapService>();
builder.Services.AddScoped<AuthService>();
var app = builder.Build();
if (app.Environment.IsDevelopment()) app.MapOpenApi();

app.MapGet("/api/v1/health", () => Results.Ok(new { status = "ok", service = "BCK Agenda API", version = "0.2.0", serverTimeUtc = DateTimeOffset.UtcNow }));
app.MapGet("/api/v1/health/database", async (PostgresProbe probe, CancellationToken ct) => { var result = await probe.CheckAsync(ct); return result.Ready ? Results.Ok(new { status = "ok", database = result.Database, foundationMigration = "applied" }) : Results.Json(new { status = "unavailable", database = result.Database, error = result.Error }, statusCode: 503); });
app.MapGet("/api/v1/system/time", () => Results.Ok(new { serverTimeUtc = DateTimeOffset.UtcNow }));

app.MapPost("/api/v1/bootstrap/company", async (CreateCompanyRequest request, BootstrapService service, CancellationToken ct) =>
{
    try { var result = await service.CreateCompanyAsync(request, ct); return Results.Created($"/api/v1/groups/{result.GroupId}", result); }
    catch (ArgumentException ex) { return Results.BadRequest(new { code = "VALIDATION_ERROR", message = ex.Message }); }
});

app.MapPost("/api/v1/auth/login", async (LoginRequest request, AuthService service, CancellationToken ct) =>
{
    var result = await service.LoginAsync(request, ct);
    return result is null ? Results.Json(new { code = "INVALID_CREDENTIALS", message = "Credenciais ou dispositivo inválidos." }, statusCode: 401) : Results.Ok(result);
});

app.MapPost("/api/v1/auth/refresh", async (RefreshRequest request, AuthService service, CancellationToken ct) =>
{
    var result = await service.RefreshAsync(request, ct);
    return result is null ? Results.Json(new { code = "INVALID_REFRESH_TOKEN", message = "Sessão expirada, revogada ou inválida." }, statusCode: 401) : Results.Ok(result);
});

app.MapPost("/api/v1/auth/logout", async (LogoutRequest request, AuthService service, CancellationToken ct) =>
{
    await service.LogoutAsync(request, ct);
    return Results.NoContent();
});

app.MapHealthChecks("/health");
app.Run();
public partial class Program { }
