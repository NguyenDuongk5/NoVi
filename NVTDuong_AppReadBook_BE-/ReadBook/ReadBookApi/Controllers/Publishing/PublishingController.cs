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
    [Authorize(Roles="1")][HttpGet("author/novels")]
    public Task<IActionResult> MyNovels(CancellationToken ct)=>Run(async()=>Ok(await repository.GetMyNovelsAsync(UserId(),ct)));
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
    public Task<IActionResult> MyChapters(Guid id,CancellationToken ct)=>Run(async()=>Ok(await repository.GetMyChaptersAsync(UserId(),id,ct)));
    [Authorize(Roles="1")][HttpPost("author/novels/{id:guid}/chapters")]
    public Task<IActionResult> CreateChapter(Guid id,ChapterWriteRequest r,CancellationToken ct)=>Run(async()=>Created("",new{id=await repository.CreateChapterAsync(UserId(),id,r,ct)}));
    [Authorize(Roles="1")][HttpPut("author/chapters/{id:guid}")]
    public Task<IActionResult> UpdateChapter(Guid id,ChapterWriteRequest r,CancellationToken ct)=>Run(async()=>Ok(new{revisionId=await repository.UpdateChapterAsync(UserId(),id,r,ct)}));
    [Authorize(Roles="1")][HttpPatch("author/chapters/{id:guid}/visibility")]
    public Task<IActionResult> ChapterVisibility(Guid id,[FromQuery]bool visible,CancellationToken ct)=>Run(async()=>{await repository.SetChapterVisibilityAsync(UserId(),id,visible,ct);return NoContent();});
    [Authorize(Roles="1")][HttpDelete("author/chapters/{id:guid}")]
    public Task<IActionResult> DeleteChapter(Guid id,CancellationToken ct)=>Run(async()=>{await repository.SoftDeleteChapterAsync(UserId(),id,ct);return NoContent();});

    [Authorize(Roles="2")][HttpGet("admin/author-applications")]
    public Task<IActionResult> AuthorQueue(CancellationToken ct)=>Run(async()=>Ok(await repository.GetAuthorApplicationsAsync(ct)));
    [Authorize(Roles="2")][HttpPost("admin/author-applications/{id:guid}/decision")]
    public Task<IActionResult> DecideAuthor(Guid id,ModerationRequest r,CancellationToken ct)=>Run(async()=>{await repository.DecideAuthorApplicationAsync(UserId(),id,r,ct);return NoContent();});
    [Authorize(Roles="2")][HttpGet("admin/moderation")]
    public Task<IActionResult> Queue(CancellationToken ct)=>Run(async()=>Ok(await repository.GetModerationQueueAsync(ct)));
    [Authorize(Roles="2")][HttpPost("admin/moderation/{type}/{id:guid}/decision")]
    public Task<IActionResult> Decide(string type,Guid id,ModerationRequest r,CancellationToken ct)=>Run(async()=>{await repository.DecideAsync(UserId(),type,id,r,ct);return NoContent();});

    private Guid UserId()=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private static async Task<IActionResult> Run(Func<Task<IActionResult>> action){try{return await action();}catch(PublishingException e){return new ObjectResult(new{message=e.Message}){StatusCode=e.StatusCode};}}
}
