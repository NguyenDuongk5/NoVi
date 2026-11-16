using ReadBookRepo.Base;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ReadBookRepo.Entity.Chapters.Entity
{
    /// <summary>
    /// Entity ánh xạ với bảng chapter trong database.
    /// </summary>
    [Table("chapter")]
    public class ChapterEntity : CRUDEntity
    {   
        /// <summary>
        /// Khóa chính bản chapter
        /// </summary>
        [Key]
        public Guid chapter_id { get; set; }

        /// <summary>
        /// Khóa phụ (id truyện)
        /// </summary>
        public Guid manga_id { get; set; }

        /// <summary>
        /// Thứ tự chapter
        /// </summary>
        public int chapter_number { get; set; }

        /// <summary>
        /// Nội dung chap
        /// </summary>
        public string chapter_content { get; set; }

        /// <summary>
        /// Tiêu đề chap
        /// </summary>
        public string chapter_title { get; set; } = string.Empty;

    }
}
