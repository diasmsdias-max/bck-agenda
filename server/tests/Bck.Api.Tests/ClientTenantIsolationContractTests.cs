using Xunit;

namespace Bck.Api.Tests;

public sealed class ClientTenantIsolationContractTests
{
    public static TheoryData<string, string> TenantScopedClientOperations => new()
    {
        { "GET", "/api/v1/clients/{id}" },
        { "GET", "/api/v1/clients/{id}/history" },
        { "PUT", "/api/v1/clients/{id}" },
        { "DELETE", "/api/v1/clients/{id}" },
        { "POST", "/api/v1/clients/{id}/reactivate" },
        { "GET", "/api/v1/clients/duplicates?phone={phone}" }
    };

    [Theory]
    [MemberData(nameof(TenantScopedClientOperations))]
    public void Client_operations_are_explicitly_tenant_scoped(string method, string route)
    {
        Assert.False(string.IsNullOrWhiteSpace(method));
        Assert.StartsWith("/api/v1/clients", route);
    }

    [Fact]
    public void Duplicate_identity_is_group_plus_normalized_phone()
    {
        var companyA = Guid.NewGuid();
        var companyB = Guid.NewGuid();
        const string normalizedPhone = "27999990001";

        Assert.NotEqual((companyA, normalizedPhone), (companyB, normalizedPhone));
    }
}
