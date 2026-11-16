using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookService.Auth;

namespace ReadBookApi.Controllers.Auth;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(IAuthService authService) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        try
        {
            return Ok(await authService.RegisterAsync(request, cancellationToken));
        }
        catch (AuthConflictException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        try
        {
            return Ok(await authService.LoginAsync(request, cancellationToken));
        }
        catch (AuthFailedException exception)
        {
            return Unauthorized(new { message = exception.Message });
        }
        catch (AccountLockedException exception)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = exception.Message });
        }
    }

    [AllowAnonymous]
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken cancellationToken)
    {
        await authService.RequestPasswordResetAsync(request, cancellationToken);
        return Accepted(new { message = "Nếu email tồn tại, mã OTP đã được gửi." });
    }

    [AllowAnonymous]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        try
        {
            await authService.ResetPasswordAsync(request, cancellationToken);
            return NoContent();
        }
        catch (InvalidOtpException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
    }
}
