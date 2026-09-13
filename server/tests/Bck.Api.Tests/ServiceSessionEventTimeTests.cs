using Bck.Api.Features.ServiceSessions;
using Xunit;

namespace Bck.Api.Tests;

public sealed class ServiceSessionEventTimeTests
{
    private static readonly DateTimeOffset ReceivedAt = DateTimeOffset.Parse("2026-09-13T15:00:00Z");

    [Fact]
    public void Resolve_UsesServerReceiptTimeWhenClientTimestampIsMissing()
    {
        Assert.Equal(ReceivedAt, ServiceSessionEventTime.Resolve(null, ReceivedAt));
    }

    [Fact]
    public void Resolve_PreservesDelayedOfflineEventTimeInUtc()
    {
        var offlineEvent = DateTimeOffset.Parse("2026-09-13T10:30:00-03:00");
        Assert.Equal(DateTimeOffset.Parse("2026-09-13T13:30:00Z"), ServiceSessionEventTime.Resolve(offlineEvent, ReceivedAt));
    }

    [Fact]
    public void Resolve_AllowsSmallClockSkewButRejectsImplausibleFutureTime()
    {
        Assert.Equal(ReceivedAt.AddMinutes(5), ServiceSessionEventTime.Resolve(ReceivedAt.AddMinutes(5), ReceivedAt));
        var error = Assert.Throws<ArgumentException>(() => ServiceSessionEventTime.Resolve(ReceivedAt.AddMinutes(5).AddTicks(1), ReceivedAt));
        Assert.Equal("OCCURRED_AT_IN_FUTURE", error.Message);
    }
}
