namespace Bck.Api.Features.ServiceSessions;

public sealed record ServiceSessionSummary(
    Guid Id,
    Guid AppointmentId,
    Guid ProfessionalUserId,
    Guid? ClientId,
    string ClientName,
    string? ClientPhone,
    string Status,
    string? Notes,
    decimal Subtotal,
    decimal DiscountTotal,
    decimal Total,
    DateTimeOffset CreatedAt,
    DateTimeOffset? FinishedAt,
    DateTimeOffset? ArrivedAt,
    DateTimeOffset? ServiceStartedAt,
    DateTimeOffset? ServiceFinishedAt,
    int? EffectiveDurationMinutes);

public sealed record ServiceSessionItemSummary(
    Guid Id,
    string ItemType,
    Guid? ServiceId,
    Guid? SourceItemId,
    string Name,
    decimal Quantity,
    decimal UnitPrice,
    decimal DiscountAmount,
    decimal LineSubtotal,
    decimal LineTotal);

public sealed record ServiceSessionHistorySummary(
    Guid Id,
    string Action,
    Guid ChangedByUserId,
    string? BeforeJson,
    string? AfterJson,
    DateTimeOffset ChangedAt);

public sealed record OpenServiceSessionRequest(Guid AppointmentId, string? Notes = null);

public sealed record AddServiceSessionItemRequest(
    string ItemType,
    Guid? ServiceId,
    Guid? SourceItemId,
    string Name,
    decimal Quantity,
    decimal UnitPrice,
    decimal DiscountAmount = 0);

public sealed record FinishServiceSessionRequest(string? Notes = null);
