using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using ReadBookRepo.PersonalReading;
using ReadBookRepo.Publishing;

namespace ReadBookApi.Controllers.PersonalReading;

public sealed class ReadingOptions{public const string SectionName="Reading";public int ViewDeduplicationMinutes{get;init;}=30;}
[ApiController,Authorize,Route("api/me")]
public sealed class PersonalReadingController(IPersonalReadingRepository repository,IOptions<ReadingOptions> options):ControllerBase
{
    private Guid UserId()=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private async Task<IActionResult> Run(Func<Task<IActionResult>> action){try{return await action();}catch(PublishingException e){return new ObjectResult(new{message=e.Message}){StatusCode=e.StatusCode};}}
    [HttpPut("library/{novelId:guid}")]public Task<IActionResult> Save(Guid novelId,CancellationToken ct)=>Run(async()=>{await repository.SaveAsync(UserId(),novelId,ct);return NoContent();});
    [HttpDelete("library/{novelId:guid}")]public Task<IActionResult> Remove(Guid novelId,CancellationToken ct)=>Run(async()=>{await repository.RemoveAsync(UserId(),novelId,ct);return NoContent();});
    [HttpGet("library")]public Task<IActionResult> Library(int page=1,int pageSize=20,string sort="saved",CancellationToken ct=default)=>Run(async()=>Ok(await repository.ListAsync(UserId(),page,pageSize,sort,ct)));
    [HttpGet("history")]public Task<IActionResult> History(int page=1,int pageSize=20,CancellationToken ct=default)=>Run(async()=>Ok(await repository.HistoryAsync(UserId(),page,pageSize,ct)));
    [HttpPost("novels/{novelId:guid}/chapters/{chapterId:guid}/sessions")]public Task<IActionResult> Begin(Guid novelId,Guid chapterId,CancellationToken ct)=>Run(async()=>Ok(await repository.BeginAsync(UserId(),novelId,chapterId,ct)));
    [HttpPut("novels/{novelId:guid}/chapters/{chapterId:guid}/progress")]public Task<IActionResult> Progress(Guid novelId,Guid chapterId,ProgressRequest request,CancellationToken ct)=>Run(async()=>Ok(await repository.UpdateProgressAsync(UserId(),novelId,chapterId,request,ct)));
    [HttpGet("novels/{novelId:guid}/continue")]public Task<IActionResult> Continue(Guid novelId,CancellationToken ct)=>Run(async()=>{var p=await repository.ContinueAsync(UserId(),novelId,ct);return p is null?NotFound():Ok(p);});
    [HttpPost("novels/{novelId:guid}/chapters/{chapterId:guid}/views")]public Task<IActionResult> View(Guid novelId,Guid chapterId,CancellationToken ct)=>Run(async()=>Ok(await repository.RecordViewAsync(UserId(),novelId,chapterId,options.Value.ViewDeduplicationMinutes,ct)));
}
