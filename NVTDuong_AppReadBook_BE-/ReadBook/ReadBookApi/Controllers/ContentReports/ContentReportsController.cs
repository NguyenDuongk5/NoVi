using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.ContentReports;

namespace ReadBookApi.Controllers.ContentReports;

[ApiController, Route("api")]
public sealed class ContentReportsController(IContentReportRepository repository) : ControllerBase
{
    [Authorize, HttpPost("content-reports")]
    public Task<IActionResult> Create(CreateContentReportRequest request, CancellationToken ct) => Run(async () =>
        Created("", new { reportId = await repository.CreateAsync(UserId(), request, ct) }));

    [Authorize(Roles = "2"), HttpGet("admin/content-reports")]
    public Task<IActionResult> Queue([FromQuery] sbyte? status, [FromQuery] sbyte? targetType,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Run(async () => Ok(await repository.GetQueueAsync(status, targetType, page, pageSize, ct)));

    [Authorize(Roles = "2"), HttpPost("admin/content-reports/{reportId:guid}/decision")]
    public Task<IActionResult> Decide(Guid reportId, DecideContentReportRequest request, CancellationToken ct) => Run(async () =>
    { await repository.DecideAsync(UserId(), reportId, request, ct); return NoContent(); });

    private Guid UserId() => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private static async Task<IActionResult> Run(Func<Task<IActionResult>> action)
    {
        try { return await action(); }
        catch (ContentReportException exception)
        { return new ObjectResult(new { message = exception.Message }) { StatusCode = exception.StatusCode }; }
    }
}
