using Bck.Api.Features.Agenda;
using Bck.Api.Features.Auth;
using Bck.Api.Features.Bootstrap;
using Bck.Api.Infrastructure.Database;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHealthChecks();
builder.Services.AddOpenApi();
builder.Services.AddSingleton<PostgresProbe>();
builder.Services.AddScoped<BootstrapService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<AgendaService>();
var app = builder.Build();
if (app.Environment.IsDevelopment()) app.MapOpenApi();

app.MapGet("/api/v1/health", () => Results.Ok(new { status = "ok", service = "BCK Agenda API", version = "0.3.0", serverTimeUtc = DateTimeOffset.UtcNow }));
app.MapGet("/api/v1/health/database", async (PostgresProbe probe, CancellationToken ct) => { var result = await probe.CheckAsync(ct); return result.Ready ? Results.Ok(new { status = "ok", database = result.Database, foundationMigration = "applied" }) : Results.Json(new { status = "unavailable", database = result.Database, error = result.Error }, statusCode: 503); });
app.MapGet("/api/v1/system/time", () => Results.Ok(new { serverTimeUtc = DateTimeOffset.UtcNow }));

app.MapPost("/api/v1/bootstrap/company", async (CreateCompanyRequest request, BootstrapService service, CancellationToken ct) => { try { var result = await service.CreateCompanyAsync(request, ct); return Results.Created($"/api/v1/groups/{result.GroupId}", result); } catch (ArgumentException ex) { return Results.BadRequest(new { code = "VALIDATION_ERROR", message = ex.Message }); } });
app.MapPost("/api/v1/auth/login", async (LoginRequest request, AuthService service, CancellationToken ct) => { var result = await service.LoginAsync(request, ct); return result is null ? Results.Json(new { code = "INVALID_CREDENTIALS", message = "Credenciais ou dispositivo inválidos." }, statusCode: 401) : Results.Ok(result); });
app.MapPost("/api/v1/auth/refresh", async (RefreshRequest request, AuthService service, CancellationToken ct) => { var result = await service.RefreshAsync(request, ct); return result is null ? Results.Json(new { code = "INVALID_REFRESH_TOKEN", message = "Sessão expirada, revogada ou inválida." }, statusCode: 401) : Results.Ok(result); });
app.MapPost("/api/v1/auth/logout", async (LogoutRequest request, AuthService service, CancellationToken ct) => { await service.LogoutAsync(request, ct); return Results.NoContent(); });

app.MapPost("/api/v1/clients", async (CreateClientRequest request, AgendaService service, CancellationToken ct) => { try { var result=await service.CreateClientAsync(request,ct); return Results.Created($"/api/v1/clients/{result.Id}",result); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
app.MapGet("/api/v1/clients", async (Guid groupId, string? q, AgendaService service, CancellationToken ct) => Results.Ok(await service.SearchClientsAsync(groupId,q,ct)));
app.MapPost("/api/v1/services", async (CreateServiceRequest request, AgendaService service, CancellationToken ct) => { try { var result=await service.CreateServiceAsync(request,ct); return Results.Created($"/api/v1/services/{result.Id}",result); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
app.MapGet("/api/v1/services", async (Guid groupId, AgendaService service, CancellationToken ct) => Results.Ok(await service.ListServicesAsync(groupId,ct)));
app.MapGet("/api/v1/appointments/availability", async (Guid groupId, Guid professionalUserId, DateTimeOffset startsAt, DateTimeOffset endsAt, AgendaService service, CancellationToken ct) => { try { return Results.Ok(await service.CheckAvailabilityAsync(groupId,professionalUserId,startsAt,endsAt,ct)); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
app.MapPost("/api/v1/appointments", async (CreateAppointmentRequest request, AgendaService service, CancellationToken ct) => { try { var result=await service.CreateAppointmentAsync(request,ct); return Results.Created($"/api/v1/appointments/{result.Id}",result); } catch(InvalidOperationException ex) when(ex.Message=="APPOINTMENT_CONFLICT") { return Results.Conflict(new { code="APPOINTMENT_CONFLICT",message="Já existe atendimento do profissional nesse intervalo." }); } catch(ArgumentException ex) { return Results.BadRequest(new { code="VALIDATION_ERROR",message=ex.Message }); } });
app.MapGet("/api/v1/appointments", async (Guid groupId, Guid professionalUserId, DateTimeOffset from, DateTimeOffset to, AgendaService service, CancellationToken ct) => Results.Ok(await service.ListAppointmentsAsync(groupId,professionalUserId,from,to,ct)));

app.MapHealthChecks("/health");
app.Run();
public partial class Program { }
