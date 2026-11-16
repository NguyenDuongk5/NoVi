using ReadBookRepo.Auth;
using System.Security.Cryptography;

namespace ReadBookService.Auth;

public sealed class AuthService(IAuthRepository repository, ITokenService tokenService, IEmailSender emailSender) : IAuthService
{
    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var email = NormalizeEmail(request.Email);
        if (await repository.EmailExistsAsync(email, cancellationToken))
            throw new AuthConflictException("Email đã được sử dụng.");

        var fullName = request.FullName.Trim();
        var user = new AuthUserRecord
        {
            UserId = Guid.NewGuid(),
            FullName = fullName,
            DisplayName = fullName,
            Email = email,
            PasswordHash = PasswordHashing.Hash(request.Password),
            Role = 0,
            Status = 1
        };

        await repository.CreateAsync(user, cancellationToken);
        return CreateResponse(user);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var user = await repository.GetByEmailAsync(NormalizeEmail(request.Email), cancellationToken);
        if (user is null || !PasswordHashing.Verify(request.Password, user.PasswordHash))
            throw new AuthFailedException("Email hoặc mật khẩu không chính xác.");
        if (user.Status != 1)
            throw new AccountLockedException("Tài khoản đang bị khóa.");

        return CreateResponse(user);
    }

    public async Task<AuthUserDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await GetRequiredUserAsync(userId, cancellationToken);
        return ToDto(user);
    }

    public async Task<AuthUserDto> UpdateProfileAsync(Guid userId, UpdateProfileRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetRequiredUserAsync(userId, cancellationToken);
        var fullName = request.FullName.Trim();
        var displayName = string.IsNullOrWhiteSpace(request.DisplayName) ? fullName : request.DisplayName.Trim();
        var avatarUrl = string.IsNullOrWhiteSpace(request.AvatarUrl) ? null : request.AvatarUrl.Trim();

        await repository.UpdateProfileAsync(userId, fullName, displayName, avatarUrl, cancellationToken);
        return new AuthUserDto(user.UserId, fullName, displayName, avatarUrl, user.Email, user.Role);
    }

    public async Task ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetRequiredUserAsync(userId, cancellationToken);
        if (!PasswordHashing.Verify(request.CurrentPassword, user.PasswordHash))
            throw new AuthFailedException("Mật khẩu hiện tại không chính xác.");
        if (PasswordHashing.Verify(request.NewPassword, user.PasswordHash))
            throw new AuthConflictException("Mật khẩu mới phải khác mật khẩu hiện tại.");

        await repository.UpdatePasswordAsync(userId, PasswordHashing.Hash(request.NewPassword), cancellationToken);
    }

    public async Task RequestPasswordResetAsync(ForgotPasswordRequest request, CancellationToken cancellationToken = default)
    {
        var email = NormalizeEmail(request.Email);
        var user = await repository.GetByEmailAsync(email, cancellationToken);
        if (user is null || user.Status != 1)
            return;

        var otp = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        await repository.CreatePasswordResetAsync(new PasswordResetRecord
        {
            ResetId = Guid.NewGuid(),
            UserId = user.UserId,
            OtpHash = PasswordHashing.Hash(otp),
            ExpiresAt = DateTime.UtcNow.AddMinutes(10)
        }, cancellationToken);
        await emailSender.SendPasswordResetOtpAsync(email, otp, cancellationToken);
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken = default)
    {
        var reset = await repository.GetActivePasswordResetAsync(NormalizeEmail(request.Email), cancellationToken);
        if (reset is null || reset.ExpiresAt <= DateTime.UtcNow || reset.AttemptCount >= 5)
            throw new InvalidOtpException("Mã OTP không hợp lệ hoặc đã hết hạn.");
        if (!PasswordHashing.Verify(request.Otp, reset.OtpHash))
        {
            await repository.IncrementPasswordResetAttemptAsync(reset.ResetId, cancellationToken);
            throw new InvalidOtpException("Mã OTP không hợp lệ hoặc đã hết hạn.");
        }
        await repository.CompletePasswordResetAsync(reset.ResetId, reset.UserId,
            PasswordHashing.Hash(request.NewPassword), cancellationToken);
    }

    private AuthResponse CreateResponse(AuthUserRecord user)
    {
        var dto = ToDto(user);
        var token = tokenService.CreateAccessToken(dto);
        return new AuthResponse(token.Token, token.ExpiresAtUtc, dto);
    }

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    private async Task<AuthUserRecord> GetRequiredUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await repository.GetByIdAsync(userId, cancellationToken);
        return user ?? throw new UserNotFoundException("Không tìm thấy tài khoản.");
    }

    private static AuthUserDto ToDto(AuthUserRecord user) =>
        new(user.UserId, user.FullName, user.DisplayName, user.AvatarUrl, user.Email, user.Role);
}
