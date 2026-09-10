using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Bck.Api.Features.Auth;

public sealed record AccessIdentity(Guid GroupId, Guid UserId, Guid DeviceId, string Profile, bool IsOwner, int PermissionVersion, int SecurityVersion);

public sealed class JwtTokenService(IConfiguration configuration)
{
    public const string Issuer = "BCK Agenda";
    public const string Audience = "BCK Agenda Clients";
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(15);

    public string Create(AccessIdentity identity, DateTimeOffset now, out DateTimeOffset expiresAt)
    {
        expiresAt = now.Add(Lifetime);
        var credentials = new SigningCredentials(new SymmetricSecurityKey(GetSigningKey(configuration)), SecurityAlgorithms.HmacSha256);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, identity.UserId.ToString()),
            new Claim("group_id", identity.GroupId.ToString()),
            new Claim("device_id", identity.DeviceId.ToString()),
            new Claim("profile", identity.Profile),
            new Claim("is_owner", identity.IsOwner ? "true" : "false"),
            new Claim("permission_version", identity.PermissionVersion.ToString()),
            new Claim("security_version", identity.SecurityVersion.ToString()),
        };
        var token = new JwtSecurityToken(Issuer, Audience, claims, now.UtcDateTime, expiresAt.UtcDateTime, credentials);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public static byte[] GetSigningKey(IConfiguration configuration)
    {
        var value = configuration["Auth:JwtSigningKey"] ?? Environment.GetEnvironmentVariable("BCK_JWT_SIGNING_KEY");
        if (string.IsNullOrWhiteSpace(value) || Encoding.UTF8.GetByteCount(value) < 32)
            throw new InvalidOperationException("JWT signing key must contain at least 32 bytes.");
        return Encoding.UTF8.GetBytes(value);
    }
}
