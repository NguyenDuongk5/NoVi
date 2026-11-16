namespace ReadBookService.Auth;

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default);
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);
    Task<AuthUserDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<AuthUserDto> UpdateProfileAsync(Guid userId, UpdateProfileRequest request, CancellationToken cancellationToken = default);
    Task ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken = default);
    Task RequestPasswordResetAsync(ForgotPasswordRequest request, CancellationToken cancellationToken = default);
    Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken = default);
}

public interface ITokenService
{
    (string Token, DateTime ExpiresAtUtc) CreateAccessToken(AuthUserDto user);
}

public sealed class AuthConflictException(string message) : Exception(message);
public sealed class AuthFailedException(string message) : Exception(message);
public sealed class AccountLockedException(string message) : Exception(message);
public sealed class UserNotFoundException(string message) : Exception(message);
public sealed class InvalidOtpException(string message) : Exception(message);

public interface IEmailSender
{
    Task SendPasswordResetOtpAsync(string recipientEmail, string otp, CancellationToken cancellationToken = default);
}
