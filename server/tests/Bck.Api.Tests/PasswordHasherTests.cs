using Bck.Api.Features.Auth;
using Xunit;

namespace Bck.Api.Tests;

public sealed class PasswordHasherTests
{
    [Fact]
    public void Hash_DoesNotStorePlainPassword_AndVerifiesCorrectPassword()
    {
        const string password = "SenhaForte123!";

        var hash = PasswordHasher.Hash(password);

        Assert.DoesNotContain(password, hash);
        Assert.StartsWith("PBKDF2-SHA256$", hash);
        Assert.True(PasswordHasher.Verify(password, hash));
    }

    [Fact]
    public void Verify_RejectsWrongPassword()
    {
        var hash = PasswordHasher.Hash("SenhaCorreta123!");

        Assert.False(PasswordHasher.Verify("SenhaErrada123!", hash));
    }

    [Theory]
    [InlineData("")]
    [InlineData("invalido")]
    [InlineData("PBKDF2-SHA256$x$bad$bad")]
    public void Verify_RejectsMalformedHashes(string encodedHash)
    {
        Assert.False(PasswordHasher.Verify("qualquer", encodedHash));
    }

    [Fact]
    public void Hash_UsesRandomSalt()
    {
        const string password = "MesmaSenha123!";

        var first = PasswordHasher.Hash(password);
        var second = PasswordHasher.Hash(password);

        Assert.NotEqual(first, second);
        Assert.True(PasswordHasher.Verify(password, first));
        Assert.True(PasswordHasher.Verify(password, second));
    }
}
