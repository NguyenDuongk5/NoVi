using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookService.Auth;

namespace ReadBookApi.Controllers.Users;

[ApiController]
[Authorize]
[Route("api/users/me")]
public sealed class UsersController(IAuthService authService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<AuthUserDto>> GetProfile(CancellationToken cancellationToken)
    {
        return Ok(await authService.GetProfileAsync(GetUserId(), cancellationToken));
    }

    [HttpPatch]
    public async Task<ActionResult<AuthUserDto>> UpdateProfile(UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        return Ok(await authService.UpdateProfileAsync(GetUserId(), request, cancellationToken));
    }

    [HttpPut("password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        try
        {
            await authService.ChangePasswordAsync(GetUserId(), request, cancellationToken);
            return NoContent();
        }
        catch (AuthFailedException exception)
        {
            return BadRequest(new { message = exception.Message });
        }
        catch (AuthConflictException exception)
        {
            return Conflict(new { message = exception.Message });
        }
    }

    private Guid GetUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(value, out var userId))
            throw new UnauthorizedAccessException("Token không chứa định danh người dùng hợp lệ.");
        return userId;
    }
}
