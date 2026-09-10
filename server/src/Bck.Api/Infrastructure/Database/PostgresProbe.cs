using Npgsql;

namespace Bck.Api.Infrastructure.Database;

public sealed class PostgresProbe(IConfiguration configuration)
{
    public async Task<PostgresProbeResult> CheckAsync(CancellationToken cancellationToken = default)
    {
        var connectionString = configuration.GetConnectionString("Postgres")
            ?? Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return new(false, null, "PostgreSQL connection is not configured.");
        }

        try
        {
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            await using var command = new NpgsqlCommand(
                "select current_database(), exists(select 1 from information_schema.tables where table_schema='public' and table_name='bck_group')",
                connection);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            await reader.ReadAsync(cancellationToken);

            var database = reader.GetString(0);
            var foundationApplied = reader.GetBoolean(1);
            return new(foundationApplied, database, foundationApplied ? null : "Foundation migration is not applied.");
        }
        catch (Exception ex)
        {
            return new(false, null, ex.Message);
        }
    }
}

public sealed record PostgresProbeResult(bool Ready, string? Database, string? Error);
