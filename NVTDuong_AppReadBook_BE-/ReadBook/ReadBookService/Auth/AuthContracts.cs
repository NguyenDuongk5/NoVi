using System.ComponentModel.DataAnnotations;

namespace ReadBookService.Auth;

public sealed class RegisterRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string FullName { get; init; } = string.Empty;

    [Required, EmailAddress, StringLength(191)]
    public string Email { get; init; } = string.Empty;

    [Required, StringLength(128, MinimumLength = 8)]
    public string Password { get; init; } = string.Empty;

    [Required, Compare(nameof(Password))]
    public string ConfirmPassword { get; init; } = string.Empty;
}

public sealed class LoginRequest
{
    [Required, EmailAddress, StringLength(191)]
    public string Email { get; init; } = string.Empty;

    [Required, StringLength(128)]
    public string Password { get; init; } = string.Empty;
}

public sealed record AuthUserDto(
    Guid UserId,
    string FullName,
    string? DisplayName,
    string? AvatarUrl,
    string Email,
    byte Role);

public sealed record AuthResponse(string AccessToken, DateTime ExpiresAtUtc, AuthUserDto User);

public sealed class UpdateProfileRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string FullName { get; init; } = string.Empty;

    [StringLength(100)]
    public string? DisplayName { get; init; }

    [Url, StringLength(500)]
    public string? AvatarUrl { get; init; }
}

public sealed class ChangePasswordRequest
{
    [Required, StringLength(128)]
    public string CurrentPassword { get; init; } = string.Empty;

    [Required, StringLength(128, MinimumLength = 8)]
    public string NewPassword { get; init; } = string.Empty;

    [Required, Compare(nameof(NewPassword))]
    public string ConfirmNewPassword { get; init; } = string.Empty;
}

public sealed class ForgotPasswordRequest
{
    [Required, EmailAddress, StringLength(191)]
    public string Email { get; init; } = string.Empty;
}

public sealed class ResetPasswordRequest
{
    [Required, EmailAddress, StringLength(191)]
    public string Email { get; init; } = string.Empty;

    [Required, RegularExpression("^[0-9]{6}$")]
    public string Otp { get; init; } = string.Empty;

    [Required, StringLength(128, MinimumLength = 8)]
    public string NewPassword { get; init; } = string.Empty;

    [Required, Compare(nameof(NewPassword))]
    public string ConfirmNewPassword { get; init; } = string.Empty;
}
