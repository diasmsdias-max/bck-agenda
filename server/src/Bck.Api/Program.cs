using Bck.Api.Features.Bootstrap;
using Bck.Api.Infrastructure.Database;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();
builder.Services.AddOpenApi();
builder.Services.AddSingleton<PostgresProbe>();
builder.Services.AddScoped<BootstrapService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/api/v1/health", () => Results.Ok(new
{
    status = "ok",
    service = "BCK Agenda API",
    version = "0.2.0",
    serverTimeUtc = DateTimeOffset.UtcNow
}));

app.MapGet("/api/v1/health/database", async (PostgresProbe probe, CancellationToken ct) =>
{
    var result = await probe.CheckAsync(ct);
    return result.Ready
        ? Results.Ok(new { status = "ok", database = result.Database, foundationMigration = "applied" })
        : Results.Json(new { status = "unavailable", database = result.Database, error = result.Error }, statusCode: 503);
});

app.MapGet("/api/v1/system/time", () => Results.Ok(new
{
    serverTimeUtc = DateTimeOffset.UtcNow
}));

app.MapPost("/api/v1/bootstrap/company", async (CreateCompanyRequest request, BootstrapService service, CancellationToken ct) =>
{
    try
    {
        var result = await service.CreateCompanyAsync(request, ct);
        return Results.Created($"/api/v1/groups/{result.GroupId}", result);
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(new { code = "VALIDATION_ERROR", message = ex.Message });
    }
});

app.MapHealthChecks("/health");

app.Run();

public partial class Program { }
