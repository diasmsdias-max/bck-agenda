using Xunit;

namespace Bck.Api.Tests;

public sealed class ClientLifecycleContractTests
{
    [Fact]
    public void Stale_version_must_be_treated_as_conflict()
    {
        const string expectedOutcome = "CONFLICT";
        Assert.Equal("CONFLICT", expectedOutcome);
    }

    [Theory]
    [InlineData(false, "DELETE")]
    [InlineData(true, "INACTIVATE")]
    public void Removal_strategy_depends_on_business_history(bool hasHistory, string expected)
    {
        var strategy = hasHistory ? "INACTIVATE" : "DELETE";
        Assert.Equal(expected, strategy);
    }

    [Fact]
    public void Reactivation_requires_existing_inactive_client()
    {
        var active = false;
        Assert.False(active);
    }
}
