var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/api/v1/health", () => Results.Ok(new
{
    status = "ok",
    service = "BCK Agenda API",
    version = "0.1.0",
    serverTimeUtc = DateTimeOffset.UtcNow
}));

app.MapGet("/api/v1/system/time", () => Results.Ok(new
{
    serverTimeUtc = DateTimeOffset.UtcNow
}));

app.MapHealthChecks("/health");

app.Run();

public partial class Program { }
