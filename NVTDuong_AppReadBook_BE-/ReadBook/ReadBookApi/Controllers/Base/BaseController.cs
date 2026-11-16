using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Base.Param;
using ReadBookRepo.Entity.Manga;
using ReadBookService.Base;
using ReadBookService.IService.Home;
using ReadBookService.Service.Home;

/// <summary>
/// Controller nhận request từ FE, gọi service xử lý logic nghiệp vụ 
/// </summary>
namespace ReadBookApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class BaseController<Entity, Dto> : ControllerBase
    {
        /// Khai báo interface service để gọi các hàm xử lý dữ liệu Manga
        private readonly IBaseService<Entity, Dto> _baseService;

        /// <summary>
        /// Hàm khởi tạo controller, nhận service qua Dependency Injection.
        /// DI Container sẽ tự động inject service tương ứng khi khởi chạy.
        /// </summary>
        /// <param name="service">Service xử lý logic nghiệp vụ</param>
        public BaseController(IBaseService<Entity, Dto> service)
        {
            _baseService = service;
        }

        /// <summary>
        /// API lấy toàn bộ danh sách entity.
        /// GET: /[Controller]/all
        /// </summary>
        /// <returns>Danh sách entity (List&lt;Dto&gt;)</returns>
        [HttpGet("all")]
        public async Task<IActionResult> GetAll()
        {
            var result = await _baseService.GetAll();
            return Ok(result);
        }


        /// <summary>
        /// API thêm mới một entity.
        /// POST: /[Controller]/insert
        /// </summary>
        /// <param name="entity">Thông tin entity cần thêm mới</param>
        [HttpPost]
        public async Task<IActionResult> InsertRecord([FromBody] Entity entity)
        {
            if (entity == null)
                return BadRequest("Dữ liệu không hợp lệ");

            var result = await _baseService.InsertAsync(entity);
            return Ok(result);
        }

        /// <summary>
        /// API xóa entity theo Id.
        /// DELETE: /[Controller]/delete
        /// </summary>
        /// <param name="pkId">Id (khóa chính) của entity cần xóa</param>
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteRecord([FromBody] Guid pkId)
        {
            var result = await _baseService.DeleteAsync(pkId);
            return Ok(result);
        }

        /// <summary>
        /// API trả ra danh sách phân trang
        /// </summary>
        /// <param name="param"></param>
        /// <returns></returns>
        [HttpPost("paging")]
        public async Task<IActionResult> GetPaging([FromBody] MysqlParamPagingBase param)
        {
            var result = await _baseService.GetPagingAsync<Dto>(param);
            var total = await _baseService.CountAsync();
            return Ok(new { data = result, total_record = total });
        }

        /// <summary>
        /// API đếm số bản ghi
        /// </summary>
        /// <returns></returns>
        [HttpGet("count")]
        public async Task<IActionResult> GetCount()
        {
            var count = await _baseService.CountAsync();
            return Ok(count);
        }

        /// <summary>
        /// API đếm số bản ghi trong ngày
        /// </summary>
        [HttpGet("count-today")]
        public async Task<IActionResult> GetCountToday()
        {
            var count = await _baseService.CountTodayAsync();
            return Ok(count);
        }

        /// <summary>
        /// API tìm kiếm theo keyword
        /// </summary>
        /// <param name="keyword"></param>
        /// <returns></returns>
        [HttpGet("search")]
        public async Task<IActionResult> Search([FromQuery] string keyword)
        {
            var data = await _baseService.SearchAsync(keyword);
            return Ok(data);
        }
        

        /// <summary>
        /// API lấy bản ghi theo id
        /// </summary>
        /// <param name="id"></param>
        /// <returns></returns>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(Guid id)
        {
            var data = await _baseService.GetByIdAsync(id);
            if (data == null) return NotFound();
            return Ok(data);
        }

    }

}
