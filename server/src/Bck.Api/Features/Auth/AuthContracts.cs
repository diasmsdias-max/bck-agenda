namespace Bck.Api.Features.Auth;

public sealed record LoginRequest(
    Guid GroupId,
    string Username,
    string Password,
    Guid DeviceId);

public sealed record LoginResponse(
    Guid GroupId,
    Guid UserId,
    Guid DeviceId,
    string Name,
    string Profile,
    bool IsOwner,
    bool MustChangePassword,
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt,
    DateTimeOffset OfflineLeaseExpiresAt);
