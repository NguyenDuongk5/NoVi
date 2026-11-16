namespace ReadBookRepo.Auth;

public sealed class PasswordResetRecord
{
    public Guid ResetId { get; init; }
    public Guid UserId { get; init; }
    public string OtpHash { get; init; } = string.Empty;
    public DateTime ExpiresAt { get; init; }
    public DateTime? UsedAt { get; init; }
    public byte AttemptCount { get; init; }
}
