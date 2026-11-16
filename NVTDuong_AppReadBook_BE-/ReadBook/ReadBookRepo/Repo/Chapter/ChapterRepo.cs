using ReadBookRepo.Base.Repo;
using ReadBookRepo.Entity.Chapter.Dto;
using ReadBookRepo.Entity.Chapters.Entity;
using ReadBookRepo.IRepo.Chapters;

namespace ReadBookRepo.Repo.Chapters
{
    /// <summary>
    /// Kế thừa các chức năng CRUD của MySqlBaseRepo
    /// </summary>
    public class ChapterRepo : MySqlBaseRepo<ChapterEntity, ChapterDto>, IChapterRepo
    {
        public ChapterRepo(IConfiguration configuration) : base(configuration)
        {
        }
    }
}
