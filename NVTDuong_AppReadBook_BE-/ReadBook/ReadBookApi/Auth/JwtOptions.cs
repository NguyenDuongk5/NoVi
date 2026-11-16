namespace ReadBookApi.Auth;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";
    public string Issuer { get; init; } = "Novi.Api";
    public string Audience { get; init; } = "Novi.Mobile";
    public string Key { get; init; } = string.Empty;
    public int AccessTokenMinutes { get; init; } = 30;
}
