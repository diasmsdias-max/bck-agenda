namespace Bck.Api.Features.Bootstrap;

public sealed record CreateCompanyRequest(
    string CompanyName,
    string? TaxId,
    string? CompanyPhone,
    string OwnerName,
    string OwnerUsername,
    string Password,
    string DeviceId,
    string DeviceName,
    string Platform,
    string DeviceMode);

public sealed record BootstrapResponse(
    Guid GroupId,
    Guid UserId,
    Guid DeviceId,
    string CompanyName,
    string OwnerName,
    string Profile,
    bool IsOwner);
