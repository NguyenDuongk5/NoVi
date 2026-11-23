using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Administration;

namespace ReadBookApi.Controllers.Administration;

[ApiController]
[Authorize(Roles = "2")]
[Route("api/admin")]
public sealed class AdministrationController(IAdministrationRepository repository) : ControllerBase
{
    [HttpGet("users")]
    public async Task<ActionResult<PagedAdminUsers>> Users([FromQuery] string? keyword,
        [FromQuery] sbyte? role, [FromQuery] sbyte? status, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default) =>
        Ok(await repository.GetUsersAsync(keyword, role, status, page, pageSize, cancellationToken));

    [HttpPatch("users/{userId:guid}/status")]
    public async Task<IActionResult> UserStatus(Guid userId, ActiveStatusRequest request,
        CancellationToken cancellationToken) => await Run(async () =>
    {
        await repository.SetUserStatusAsync(UserId(), userId, request.Active, cancellationToken);
        return NoContent();
    });

    [HttpGet("categories")]
    public async Task<ActionResult<PagedAdminCategories>> Categories([FromQuery] string? keyword,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        Ok(await repository.GetCategoriesAsync(keyword, page, pageSize, cancellationToken));

    [HttpPost("categories")]
    public async Task<IActionResult> CreateCategory(CategoryNameRequest request,
        CancellationToken cancellationToken) => await Run(async () =>
    {
        var id = await repository.CreateCategoryAsync(request.Name, cancellationToken);
        return Created($"/api/admin/categories/{id}", new { categoryId = id });
    });

    [HttpPut("categories/{categoryId:guid}")]
    public async Task<IActionResult> UpdateCategory(Guid categoryId, CategoryNameRequest request,
        CancellationToken cancellationToken) => await Run(async () =>
    {
        await repository.UpdateCategoryAsync(categoryId, request.Name, cancellationToken);
        return NoContent();
    });

    [HttpPatch("categories/{categoryId:guid}/status")]
    public async Task<IActionResult> CategoryStatus(Guid categoryId, ActiveStatusRequest request,
        CancellationToken cancellationToken) => await Run(async () =>
    {
        await repository.SetCategoryStatusAsync(categoryId, request.Active, cancellationToken);
        return NoContent();
    });

    [HttpGet("novels")]
    public async Task<ActionResult<PagedAdminNovels>> Novels([FromQuery] string? keyword,
        [FromQuery] Guid? categoryId, [FromQuery] sbyte? reviewStatus,
        [FromQuery] sbyte? visibility, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default) =>
        Ok(await repository.GetNovelsAsync(keyword, categoryId, reviewStatus, visibility,
            page, pageSize, cancellationToken));

    [HttpGet("novels/{novelId:guid}")]
    public async Task<IActionResult> Novel(Guid novelId, CancellationToken cancellationToken)
    {
        var item = await repository.GetNovelAsync(novelId, cancellationToken);
        return item is null ? NotFound(new { message = "Không tìm thấy truyện." }) : Ok(item);
    }

    [HttpGet("novels/{novelId:guid}/chapters/{chapterId:guid}")]
    public async Task<IActionResult> NovelChapter(Guid novelId, Guid chapterId,
        CancellationToken cancellationToken)
    {
        var item = await repository.GetNovelChapterAsync(novelId, chapterId, cancellationToken);
        return item is null ? NotFound(new { message = "Không tìm thấy chương trong truyện này." }) : Ok(item);
    }

    [HttpPatch("novels/{novelId:guid}/visibility")]
    public async Task<IActionResult> NovelVisibility(Guid novelId, ActiveStatusRequest request,
        CancellationToken cancellationToken) => await Run(async () =>
    {
        await repository.SetNovelVisibilityAsync(novelId, request.Active, cancellationToken);
        return NoContent();
    });

    private Guid UserId() => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private static async Task<IActionResult> Run(Func<Task<IActionResult>> action)
    {
        try { return await action(); }
        catch (AdministrationException exception)
        { return new ObjectResult(new { message = exception.Message }) { StatusCode = exception.StatusCode }; }
    }
}
