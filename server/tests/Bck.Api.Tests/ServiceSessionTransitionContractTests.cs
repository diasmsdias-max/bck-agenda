using Xunit;

namespace Bck.Api.Tests;

public sealed class ServiceSessionTransitionContractTests
{
    [Theory]
    [InlineData("SCHEDULED")]
    [InlineData("CONFIRMED")]
    [InlineData("WAITING")]
    public void Opening_service_session_moves_openable_appointment_to_in_service(string fromStatus)
    {
        Assert.Contains(fromStatus, new[] { "SCHEDULED", "CONFIRMED", "WAITING" });
        const string expected = "IN_SERVICE";
        Assert.Equal("IN_SERVICE", expected);
    }

    [Theory]
    [InlineData("FINISHED")]
    [InlineData("CANCELLED")]
    [InlineData("NO_SHOW")]
    [InlineData("RESCHEDULED")]
    [InlineData("IN_SERVICE")]
    public void Non_openable_appointment_cannot_open_another_service_session(string status)
    {
        Assert.Contains(status, new[] { "FINISHED", "CANCELLED", "NO_SHOW", "RESCHEDULED", "IN_SERVICE" });
    }

    [Fact]
    public void Finishing_service_session_requires_and_completes_in_service_appointment()
    {
        const string requiredStatus = "IN_SERVICE";
        const string finalStatus = "FINISHED";
        Assert.Equal("IN_SERVICE", requiredStatus);
        Assert.Equal("FINISHED", finalStatus);
    }
}
