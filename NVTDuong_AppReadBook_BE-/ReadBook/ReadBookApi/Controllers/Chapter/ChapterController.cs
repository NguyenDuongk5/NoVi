using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Entity.Chapter.Dto;
using ReadBookRepo.Entity.Chapters.Entity;
using ReadBookService.IService.Chapters;
using ReadBookService.Service.Chapters;
using System;
using System.Linq;

namespace ReadBookApi.Controllers
{
    /// <summary>
    /// Controller xử lý các API liên quan đến Chapter (chương truyện).
    /// Kế thừa BaseController để sử dụng các chức năng CRUD chung.
    /// </summary>
    [ApiController]
    [Route("[controller]")]
    public class ChapterController : BaseController<ChapterEntity, ChapterDto>
    {
        private readonly IChapterService _service;

        public ChapterController(IChapterService service) : base(service)
        {
            _service = service;
        }
        /// <summary>
        /// Cập nhật chapter
        /// PUT: /Chapter/{id}
        /// </summary>
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(Guid id, [FromBody] ChapterEntity entity)
        {
            if (entity == null)
                return BadRequest("Dữ liệu không hợp lệ");

            if (id != entity.chapter_id)
                return BadRequest("Id không khớp");

            var result = await _service.UpdateAsync(entity);
            return Ok(result);
        }
    }
}
