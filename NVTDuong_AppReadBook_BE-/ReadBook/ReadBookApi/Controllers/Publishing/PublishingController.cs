using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Publishing;

namespace ReadBookApi.Controllers.Publishing;

[ApiController]
[Route("api")]
public sealed class PublishingController(IPublishingRepository repository) : ControllerBase
{
    [Authorize(Roles="0")][HttpPost("author-applications")]
    public Task<IActionResult> Apply(CreateAuthorApplication r,CancellationToken ct)=>Run(async()=>Created("",new{id=await repository.ApplyForAuthorAsync(UserId(),r,ct)}));
    [Authorize][HttpGet("author-applications/me")]
    public Task<IActionResult> MyAuthorApplication(CancellationToken ct)=>Run(async()=>{var x=await repository.GetMyAuthorApplicationAsync(UserId(),ct);return x is null?NotFound(new{message="Bạn chưa gửi yêu cầu làm tác giả."}):Ok(x);});
    [Authorize(Roles="1")][HttpGet("author/novels")]
    public Task<IActionResult> MyNovels([FromQuery]int? page,[FromQuery]int pageSize=20,CancellationToken ct=default)=>Run(async()=>Paged(await repository.GetMyNovelsAsync(UserId(),ct),page,pageSize));
    [Authorize(Roles="1")][HttpGet("author/novels/{id:guid}")]
    public Task<IActionResult> MyNovel(Guid id,CancellationToken ct)=>Run(async()=>{var x=await repository.GetMyNovelAsync(UserId(),id,ct);return x is null?NotFound():Ok(x);});
    [Authorize(Roles="1")][HttpPost("author/novels")]
    public Task<IActionResult> CreateNovel(NovelWriteRequest r,CancellationToken ct)=>Run(async()=>Created("",new{id=await repository.CreateNovelAsync(UserId(),r,ct)}));
    [Authorize(Roles="1")][HttpPut("author/novels/{id:guid}")]
    public Task<IActionResult> UpdateNovel(Guid id,NovelWriteRequest r,CancellationToken ct)=>Run(async()=>Ok(new{revisionId=await repository.UpdateNovelAsync(UserId(),id,r,ct)}));
    [Authorize(Roles="1")][HttpPatch("author/novels/{id:guid}/visibility")]
    public Task<IActionResult> NovelVisibility(Guid id,[FromQuery]bool visible,CancellationToken ct)=>Run(async()=>{await repository.SetNovelVisibilityAsync(UserId(),id,visible,ct);return NoContent();});
    [Authorize(Roles="1")][HttpDelete("author/novels/{id:guid}")]
    public Task<IActionResult> DeleteNovel(Guid id,CancellationToken ct)=>Run(async()=>{await repository.SoftDeleteNovelAsync(UserId(),id,ct);return NoContent();});
    [Authorize(Roles="1")][HttpGet("author/novels/{id:guid}/chapters")]
    public Task<IActionResult> MyChapters(Guid id,[FromQuery]int? page,[FromQuery]int pageSize=20,CancellationToken ct=default)=>Run(async()=>Paged(await repository.GetMyChaptersAsync(UserId(),id,ct),page,pageSize));
    [Authorize(Roles="1")][HttpPost("author/novels/{id:guid}/chapters")]
    public Task<IActionResult> CreateChapter(Guid id,ChapterWriteRequest r,CancellationToken ct)=>Run(async()=>Created("",new{id=await repository.CreateChapterAsync(UserId(),id,r,ct)}));
    [Authorize(Roles="1")][HttpPut("author/chapters/{id:guid}")]
    public Task<IActionResult> UpdateChapter(Guid id,ChapterWriteRequest r,CancellationToken ct)=>Run(async()=>Ok(new{revisionId=await repository.UpdateChapterAsync(UserId(),id,r,ct)}));
    [Authorize(Roles="1")][HttpPatch("author/chapters/{id:guid}/visibility")]
    public Task<IActionResult> ChapterVisibility(Guid id,[FromQuery]bool visible,CancellationToken ct)=>Run(async()=>{await repository.SetChapterVisibilityAsync(UserId(),id,visible,ct);return NoContent();});
    [Authorize(Roles="1")][HttpDelete("author/chapters/{id:guid}")]
    public Task<IActionResult> DeleteChapter(Guid id,CancellationToken ct)=>Run(async()=>{await repository.SoftDeleteChapterAsync(UserId(),id,ct);return NoContent();});

    [Authorize(Roles="2")][HttpGet("admin/author-applications")]
    public Task<IActionResult> AuthorQueue([FromQuery]int? page,[FromQuery]int pageSize=20,CancellationToken ct=default)=>Run(async()=>Paged(await repository.GetAuthorApplicationsAsync(ct),page,pageSize));
    [Authorize(Roles="2")][HttpPost("admin/author-applications/{id:guid}/decision")]
    public Task<IActionResult> DecideAuthor(Guid id,ModerationRequest r,CancellationToken ct)=>Run(async()=>{await repository.DecideAuthorApplicationAsync(UserId(),id,r,ct);return NoContent();});
    [Authorize(Roles="2")][HttpGet("admin/moderation")]
    public Task<IActionResult> Queue([FromQuery]int? page,[FromQuery]int pageSize=20,CancellationToken ct=default)=>Run(async()=>Paged(await repository.GetModerationQueueAsync(ct),page,pageSize));
    [Authorize(Roles="2")][HttpGet("admin/moderation/{type}/{id:guid}")]
    public Task<IActionResult> ModerationDetail(string type,Guid id,CancellationToken ct)=>Run(async()=>{var x=await repository.GetModerationDetailAsync(type,id,ct);return x is null?NotFound(new{message="Nội dung không còn trong hàng chờ."}):Ok(x);});
    [Authorize(Roles="2")][HttpPost("admin/moderation/{type}/{id:guid}/decision")]
    public Task<IActionResult> Decide(string type,Guid id,ModerationRequest r,CancellationToken ct)=>Run(async()=>{await repository.DecideAsync(UserId(),type,id,r,ct);return NoContent();});

    private Guid UserId()=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private IActionResult Paged<T>(IReadOnlyList<T> source,int? page,int pageSize)
    {
        if (page is null) return Ok(source); // giữ tương thích với script/client cũ
        if (page < 1 || pageSize is < 1 or > 50)
            return BadRequest(new { message="page phải >= 1 và pageSize từ 1 đến 50." });
        return Ok(new { items=source.Skip((page.Value-1)*pageSize).Take(pageSize),page=page.Value,pageSize,totalItems=source.Count });
    }
    private static async Task<IActionResult> Run(Func<Task<IActionResult>> action){try{return await action();}catch(PublishingException e){return new ObjectResult(new{message=e.Message}){StatusCode=e.StatusCode};}}
}
