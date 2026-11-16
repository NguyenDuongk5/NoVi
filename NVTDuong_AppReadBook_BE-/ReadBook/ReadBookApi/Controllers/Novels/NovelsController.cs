using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Novels;

namespace ReadBookApi.Controllers.Novels;

[ApiController]
[AllowAnonymous]
[Route("api/novels")]
public sealed class NovelsController(INovelRepository repository) : ControllerBase
{
    [HttpGet]
    public Task<PagedNovels> Search([FromQuery] string? keyword, [FromQuery] Guid? categoryId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default) =>
        repository.SearchPublicAsync(keyword, categoryId, page, pageSize, cancellationToken);

    [HttpGet("rankings")]
    public async Task<ActionResult<PagedRankings>> Rankings([FromQuery] string period = "month",
        [FromQuery] Guid? categoryId = null, [FromQuery] bool completed = false,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        if (!Enum.TryParse<RankingPeriod>(period, true, out var parsedPeriod))
            return BadRequest(new { message = "period phải là week, month hoặc all." });
        if (page < 1) return BadRequest(new { message = "page phải lớn hơn hoặc bằng 1." });
        if (pageSize is < 1 or > 50)
            return BadRequest(new { message = "pageSize phải từ 1 đến 50." });
        return Ok(await repository.GetRankingsAsync(parsedPeriod, categoryId, completed,
            page, pageSize, cancellationToken));
    }

    [HttpGet("{novelId:guid}")]
    public async Task<ActionResult<NovelDetail>> Get(Guid novelId, CancellationToken cancellationToken)
    {
        var novel = await repository.GetPublicByIdAsync(novelId, cancellationToken);
        return novel is null ? NotFound() : Ok(novel);
    }

    [HttpGet("{novelId:guid}/chapters")]
    public async Task<ActionResult<IReadOnlyList<NovelChapterItem>>> GetChapters(Guid novelId, CancellationToken cancellationToken) =>
        Ok(await repository.GetPublicChaptersAsync(novelId, cancellationToken));

    [HttpGet("chapters/{chapterId:guid}")]
    public async Task<ActionResult<PublicChapter>> GetChapter(Guid chapterId, CancellationToken cancellationToken)
    {
        var chapter = await repository.GetPublicChapterAsync(chapterId, cancellationToken);
        return chapter is null ? NotFound() : Ok(chapter);
    }
}
