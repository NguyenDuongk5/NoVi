using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookApi.Media;

namespace ReadBookApi.Controllers.Media;

[ApiController]
[Route("api/admin/media/orphans")]
[Authorize(Roles="2")]
public sealed class MediaMaintenanceController(OrphanMediaService service):ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Scan([FromQuery]int minAgeHours=24,[FromQuery]bool delete=false,CancellationToken ct=default)
    {
        try{return Ok(await service.RunAsync(minAgeHours,delete,ct));}
        catch(MediaException e){return new ObjectResult(new{message=e.Message}){StatusCode=e.StatusCode};}
    }
}
