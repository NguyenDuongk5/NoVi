using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Entity.Manga;
using ReadBookRepo.Entity.Manga.Dto;
using ReadBookService.IService.Home;
using ReadBookService.Service.Home;
namespace ReadBookApi.Controllers
{
    /// <summary>
    /// Controller xử lý các API liên quan đến Manga (truyện)
    /// Kế thừa BaseController để sử dụng các chức năng CRUD chung.
    /// </summary>
    [ApiController]
    [Route("[controller]")]
    public class MangaController : BaseController<MangaEntity, MangaDto>
    {
        /// Khai báo interface service để gọi các hàm xử lý dữ liệu Manga
        private readonly IMangaService _mangaService;

        public MangaController(IMangaService mangaService) : base(mangaService)
        {
            _mangaService = mangaService;
        }
        /// <summary>
        /// Cập nhật manga
        /// PUT: /manga/{id}
        /// </summary>
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(Guid id, [FromBody] MangaEntity entity)
        {
            if (id != entity.manga_id)
                return BadRequest("Id không khớp");

            var result = await _mangaService.UpdateAsync(entity);
            return Ok(result);
        }


    }
}
