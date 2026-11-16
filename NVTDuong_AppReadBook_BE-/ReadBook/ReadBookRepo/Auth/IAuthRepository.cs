namespace ReadBookRepo.Auth;

public interface IAuthRepository
{
    Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken = default);
    Task<AuthUserRecord?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task<AuthUserRecord?> GetByIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task CreateAsync(AuthUserRecord user, CancellationToken cancellationToken = default);
    Task UpdateProfileAsync(Guid userId, string fullName, string? displayName, string? avatarUrl, CancellationToken cancellationToken = default);
    Task UpdatePasswordAsync(Guid userId, string passwordHash, CancellationToken cancellationToken = default);
    Task CreatePasswordResetAsync(PasswordResetRecord reset, CancellationToken cancellationToken = default);
    Task<PasswordResetRecord?> GetActivePasswordResetAsync(string email, CancellationToken cancellationToken = default);
    Task IncrementPasswordResetAttemptAsync(Guid resetId, CancellationToken cancellationToken = default);
    Task CompletePasswordResetAsync(Guid resetId, Guid userId, string passwordHash, CancellationToken cancellationToken = default);
}
