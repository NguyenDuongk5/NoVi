using ReadBookRepo.Entity.Chapter.Dto;
using ReadBookRepo.Entity.Chapters.Entity;
using ReadBookRepo.IRepo.Chapters;
using ReadBookService.IService.Chapters;
using ReadBookService.Service.Base;

/// Thực thi cụ thể (gọi repo, xử lý dữ liệu, rồi trả kết quả).

namespace ReadBookService.Service.Chapters
{
    /// <summary>
    /// Kế thừa BaseService để sử dụng các chức năng chung
    /// </summary>
    public class ChapterService : BaseService<ChapterEntity, ChapterDto>, IChapterService
    {
        /// <summary>
        /// Inject IChapterRepo (chính là MysqlChapterRepo) vào để gọi database.
        /// </summary>
        private readonly IChapterRepo _chapterRepo;
        public ChapterService(IChapterRepo Repo) : base(Repo)
        {
            _chapterRepo = Repo;
        }
    }
}
