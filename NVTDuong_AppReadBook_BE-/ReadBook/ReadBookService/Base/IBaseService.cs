using ReadBookRepo.Base.Param;
using ReadBookRepo.Base.Result;

namespace ReadBookService.Base
{
    /// <summary>
    /// Interface base cho tất cả Service
    /// Entity (bảng DB)
    /// </summary>
    public interface IBaseService<Entity, Dto>
    {
        /// <summary>
        /// Hàm Insert bất đồng bộ 
        /// Truyền vào 1 entity để thêm vào DB
        /// Số dòng bị ảnh hưởng trong DB
        /// </summary>
        Task<List<Dto>> GetAll();


        /// <summary>
        /// Thêm mới 1 entity
        /// </summary>
        /// <param name="entity"></param>
        /// <returns></returns>
        Task<MysqlBaseResult> InsertAsync(Entity entity);

        /// <summary>
        /// Cập nhật 1 entity
        /// </summary>
        /// <param name="entity"></param>
        Task<MysqlBaseResult> UpdateAsync(Entity entity);

        /// <summary>
        /// Xóa 1 entity theo khóa chính
        /// </summary>
        /// <param name="pkId"></param>
        Task<MysqlBaseResult> DeleteAsync(Guid pkId);

        /// <summary>
        /// Lấy dữ liệu có phân trang
        /// </summary>
        /// <typeparam name="T">Kiểu dữ liệu trả về (thường là Dto)</typeparam>
        /// <param name="paramPagingBase">Thông tin phân trang</param>
        /// <returns>Dữ liệu phân trang + tổng số bản ghi</returns>
        Task<MysqlResultPagingBase<T>> GetPagingAsync<T>(MysqlParamPagingBase paramPagingBase);

        /// <summary>
        /// Đếm tổng số bản ghi trong bảng
        /// </summary>
        /// <returns>Số lượng bản ghi</returns>
        Task<int> CountAsync();

        /// <summary>
        /// Đếm số bản ghi được tạo trong ngày hôm nay
        /// </summary>
        /// <returns>Số lượng bản ghi trong ngày</returns>
        Task<int> CountTodayAsync();

        /// <summary>
        /// Tìm kiếm dữ liệu theo từ khóa
        /// </summary>
        /// <param name="keyword">Từ khóa tìm kiếm</param>
        /// <returns>Danh sách kết quả tìm kiếm</returns>
        Task<List<Dto>> SearchAsync(string keyword);

        /// <summary>
        /// Lấy chi tiết một bản ghi theo ID
        /// </summary>
        /// <param name="id">ID của bản ghi</param>
        /// <returns>Dto tương ứng hoặc null nếu không tồn tại</returns>
        Task<Dto?> GetByIdAsync(Guid id);


    }
}
