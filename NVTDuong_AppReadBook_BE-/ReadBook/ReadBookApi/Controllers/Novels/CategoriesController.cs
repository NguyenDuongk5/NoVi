using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Novels;

namespace ReadBookApi.Controllers.Novels;

[ApiController]
[AllowAnonymous]
[Route("api/categories")]
public sealed class CategoriesController(INovelRepository repository) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PublicCategory>>> Get(CancellationToken cancellationToken) =>
        Ok(await repository.GetActiveCategoriesAsync(cancellationToken));
}
