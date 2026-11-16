using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookApi.Media;
using ReadBookRepo.Media;
using ReadBookRepo.Publishing;
namespace ReadBookApi.Controllers.Media;
[ApiController,Route("api/media"),Authorize]
public sealed class MediaController(IMediaStorage storage,IMediaRepository repository,ILogger<MediaController> logger):ControllerBase
{
    [HttpPost("avatar"),RequestSizeLimit(2_200_000)]
    public Task<IActionResult> Avatar(IFormFile file,CancellationToken ct)=>Run(async()=>{await repository.EnsureActiveUserAsync(UserId(),ct);
using var image=await ImageFileValidator.ValidateAsync(file,2*1024*1024,ct);
var uploaded=await storage.UploadAsync(image.Stream,image.ContentType,"avatars",image.Extension,ct);
try{await repository.UpdateAvatarAsync(UserId(),uploaded.Url,ct);
}catch{await Cleanup(uploaded.ObjectName,ct);
throw;
}return Ok(new{url=uploaded.Url,image.Width,image.Height});
});
    [Authorize(Roles="1"),HttpPost("novels/{novelId:guid}/cover"),RequestSizeLimit(5_300_000)]
    public Task<IActionResult> Cover(Guid novelId,IFormFile file,CancellationToken ct)=>Run(async()=>{await repository.EnsureOwnedNovelAsync(UserId(),novelId,ct);
using var image=await ImageFileValidator.ValidateAsync(file,5*1024*1024,ct);
var uploaded=await storage.UploadAsync(image.Stream,image.ContentType,"covers",image.Extension,ct);
try{var result=await repository.SetCoverAsync(UserId(),novelId,uploaded.Url,ct);
return Ok(new{url=uploaded.Url,result.RevisionId,result.PendingApproval,image.Width,image.Height});
}catch{await Cleanup(uploaded.ObjectName,ct);
throw;
}});
    private async Task Cleanup(string name,CancellationToken ct){try{await storage.DeleteAsync(name,ct);
}catch(Exception e){logger.LogError(e,"Failed to clean newly uploaded media object {ObjectName}",name);
}}
    private Guid UserId()=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private static async Task<IActionResult> Run(Func<Task<IActionResult>> f){try{return await f();
}catch(MediaException e){return new ObjectResult(new{message=e.Message}){StatusCode=e.StatusCode};
}catch(PublishingException e){return new ObjectResult(new{message=e.Message}){StatusCode=e.StatusCode};
}}
}
