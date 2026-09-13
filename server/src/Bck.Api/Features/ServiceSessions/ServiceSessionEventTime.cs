namespace Bck.Api.Features.ServiceSessions;

public static class ServiceSessionEventTime
{
    public static readonly TimeSpan MaximumFutureClockSkew = TimeSpan.FromMinutes(5);

    public static DateTimeOffset Resolve(DateTimeOffset? occurredAt, DateTimeOffset receivedAt)
    {
        var receivedUtc = receivedAt.ToUniversalTime();
        if (occurredAt is null) return receivedUtc;
        var occurredUtc = occurredAt.Value.ToUniversalTime();
        if (occurredUtc > receivedUtc.Add(MaximumFutureClockSkew))
            throw new ArgumentException("OCCURRED_AT_IN_FUTURE");
        return occurredUtc;
    }
}
