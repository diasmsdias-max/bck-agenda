using System.Reflection;
using Bck.Api.Features.Clients;
using Xunit;

namespace Bck.Api.Tests;

public sealed class ClientManagementValidationTests
{
    [Theory]
    [InlineData("(27) 99999-0001", "27999990001")]
    [InlineData("+55 27 99999-0001", "5527999990001")]
    [InlineData("27 99999.0001", "27999990001")]
    public void NormalizePhone_keeps_only_digits(string input, string expected)
    {
        var method = typeof(ClientManagementService).GetMethod("NormalizePhone", BindingFlags.NonPublic | BindingFlags.Static)!;
        Assert.Equal(expected, method.Invoke(null, [input]));
    }

    [Fact]
    public void Create_request_defaults_whatsapp_to_true()
    {
        var request = new CreateManagedClientRequest("Maria", "27999990001");
        Assert.True(request.WhatsAppEnabled);
    }

    [Fact]
    public void Update_request_preserves_version_for_optimistic_concurrency()
    {
        var request = new UpdateManagedClientRequest("Maria", "27999990001", true, null, null, 7);
        Assert.Equal(7, request.Version);
    }
}
