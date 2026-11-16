namespace ReadBookRepo.Auth;

public sealed class AuthUserRecord
{
    public Guid UserId { get; init; }
    public string FullName { get; init; } = string.Empty;
    public string? DisplayName { get; init; }
    public string? AvatarUrl { get; init; }
    public string? Username { get; init; }
    public string Email { get; init; } = string.Empty;
    public string PasswordHash { get; init; } = string.Empty;
    public byte Role { get; init; }
    public byte Status { get; init; }
}
