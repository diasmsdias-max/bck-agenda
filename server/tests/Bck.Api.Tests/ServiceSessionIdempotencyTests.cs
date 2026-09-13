using Bck.Api.Features.ServiceSessions;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace Bck.Api.Tests;

public sealed class ServiceSessionIdempotencyTests
{
    [Fact]
    public void RequireKey_RejectsMissingHeader()
    {
        var request = new DefaultHttpContext().Request;

        var error = Assert.Throws<ArgumentException>(() => ServiceSessionIdempotency.RequireKey(request));

        Assert.Equal("IDEMPOTENCY_KEY_REQUIRED", error.Message);
    }

    [Theory]
    [InlineData("short")]
    [InlineData("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")]
    public void RequireKey_RejectsInvalidLength(string value)
    {
        var request = new DefaultHttpContext().Request;
        request.Headers[ServiceSessionIdempotency.HeaderName] = value;

        var error = Assert.Throws<ArgumentException>(() => ServiceSessionIdempotency.RequireKey(request));

        Assert.Equal("IDEMPOTENCY_KEY_INVALID", error.Message);
    }

    [Fact]
    public void RequireKey_ReturnsTrimmedValidKey()
    {
        var request = new DefaultHttpContext().Request;
        request.Headers[ServiceSessionIdempotency.HeaderName] = "  operation-123456  ";

        Assert.Equal("operation-123456", ServiceSessionIdempotency.RequireKey(request));
    }

    [Fact]
    public void RequestHash_IsStableAndChangesWithPayload()
    {
        var first = ServiceSessionIdempotency.RequestHash(new { AppointmentId = "appointment-1", Notes = "A" });
        var repeated = ServiceSessionIdempotency.RequestHash(new { AppointmentId = "appointment-1", Notes = "A" });
        var changed = ServiceSessionIdempotency.RequestHash(new { AppointmentId = "appointment-1", Notes = "B" });

        Assert.Equal(64, first.Length);
        Assert.Equal(first, repeated);
        Assert.NotEqual(first, changed);
    }
}
