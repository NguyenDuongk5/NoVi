using Microsoft.AspNetCore.Mvc;

namespace ReadBookApi.Controllers
{
    //Khai báo model để nhận dữ liệu từ form khi upload
    public class FileUploadModel
    {
        // Thuộc tính đại diện cho file gửi lên từ form
        public required IFormFile File { get; set; }
    }

    /// <summary>
    /// Controller xử lý chức năng upload file (ảnh) lên server
    /// </summary>
    [ApiController]
    [Route("[controller]")] 
    public class UploadController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;

        /// <summary>
        /// Tiêm (inject) môi trường web để lấy đường dẫn thư mục wwwroot
        /// </summary>
        /// <param name="env"></param>
        public UploadController(IWebHostEnvironment env)
        {
            _env = env;
        }

        /// <summary>
        /// API upload ảnh: POST /upload/upload-image
        /// </summary>
        /// <param name="model"></param>
        /// <returns></returns>
        [HttpPost("upload-image")]
        public async Task<IActionResult> UploadImage([FromForm] FileUploadModel model)
        {
            await Task.CompletedTask;
            return StatusCode(StatusCodes.Status410Gone, new { message = "Legacy upload is disabled. Use authenticated /api/media endpoints." });
            #pragma warning disable CS0162
            // Lấy file từ model
            var file = model.File;

            // Nếu không có file thì báo lỗi
            if (file == null || file.Length == 0)
                return BadRequest("No file uploaded.");

            // Xác định thư mục lưu file: wwwroot/uploads
            var uploadPath = Path.Combine(
                _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"),
                "uploads"
            );

            // Nếu thư mục chưa tồn tại → tạo mới
            if (!Directory.Exists(uploadPath))
            {
                Directory.CreateDirectory(uploadPath);
            }

            // Tạo tên file ngẫu nhiên bằng Guid để tránh trùng
            var fileName = $"{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";
            var filePath = Path.Combine(uploadPath, fileName);

            // Ghi file xuống ổ đĩa
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            // Tạo URL đầy đủ để truy cập ảnh
            var imageUrl = $"{Request.Scheme}://{Request.Host}/uploads/{fileName}";

            // Trả về kết quả thành công kèm đường dẫn ảnh
            return Ok(new { url = imageUrl });
            #pragma warning restore CS0162
        }
    }
}
