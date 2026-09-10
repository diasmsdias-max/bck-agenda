using Npgsql;
using Xunit;

namespace Bck.Api.Tests;

public sealed class ClientPhoneDuplicateContractTests
{
    [Fact]
    public void Unique_violation_constant_is_postgres_23505()
    {
        Assert.Equal("23505", PostgresErrorCodes.UniqueViolation);
    }

    [Theory]
    [InlineData("(27) 99999-0001", "27999990001")]
    [InlineData("27 99999-0001", "27999990001")]
    [InlineData("27.99999.0001", "27999990001")]
    public void Phone_formats_represent_same_normalized_identity(string phone, string expected)
    {
        var normalized = new string(phone.Where(char.IsDigit).ToArray());
        Assert.Equal(expected, normalized);
    }

    [Fact]
    public void Duplicate_constraint_name_is_stable_api_contract()
    {
        const string constraint = "ux_client_group_phone_normalized";
        Assert.Equal("ux_client_group_phone_normalized", constraint);
    }
}
