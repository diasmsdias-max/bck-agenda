namespace Bck.Api.Features.Auth;

public sealed record LoginRequest(Guid GroupId,string Username,string Password,Guid DeviceId);
public sealed record LoginResponse(Guid GroupId,Guid UserId,Guid DeviceId,string Name,string Profile,bool IsOwner,bool MustChangePassword,string AccessToken,DateTimeOffset AccessTokenExpiresAt,string RefreshToken,DateTimeOffset RefreshTokenExpiresAt,DateTimeOffset OfflineLeaseExpiresAt,DateTimeOffset ServerTimeUtc,DateTimeOffset ValidatedAt);
public sealed record RefreshRequest(string RefreshToken);
public sealed record LogoutRequest(string RefreshToken);
public sealed record RefreshResponse(string AccessToken,DateTimeOffset AccessTokenExpiresAt,string RefreshToken,DateTimeOffset RefreshTokenExpiresAt,DateTimeOffset OfflineLeaseExpiresAt,DateTimeOffset ServerTimeUtc,DateTimeOffset ValidatedAt);
