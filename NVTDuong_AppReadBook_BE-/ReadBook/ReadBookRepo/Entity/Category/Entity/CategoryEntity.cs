using ReadBookRepo.Base;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ReadBookRepo.Entity.Category
{
    /// <summary>
    /// Entity ánh xạ với bảng category trong database.
    /// Lưu trữ thông tin danh mục truyện.
    /// </summary>
    [Table("category")]
    public class CategoryEntity
    {   
        /// <summary>
        /// Khóa chính
        /// </summary>
        [Key]
        public Guid category_id { get; set; }

        /// <summary>
        /// Tên thể loại
        /// </summary>
        public string category_name { get; set; }

        /// <summary>
        /// Danh sách id truyện
        /// </summary>
        public string list_manga_id { get; set; }
    }
}
