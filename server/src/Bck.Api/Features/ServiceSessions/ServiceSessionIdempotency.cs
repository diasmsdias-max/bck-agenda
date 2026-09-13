using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Bck.Api.Features.ServiceSessions;

public static class ServiceSessionIdempotency
{
    public const string HeaderName = "Idempotency-Key";

    public static string RequireKey(HttpRequest request)
    {
        if (!request.Headers.TryGetValue(HeaderName, out var values))
            throw new ArgumentException("IDEMPOTENCY_KEY_REQUIRED");

        var key = values.ToString().Trim();
        if (key.Length is < 8 or > 128)
            throw new ArgumentException("IDEMPOTENCY_KEY_INVALID");

        return key;
    }

    public static string RequestHash<T>(T request)
    {
        var json = JsonSerializer.Serialize(request);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))).ToLowerInvariant();
    }
}
