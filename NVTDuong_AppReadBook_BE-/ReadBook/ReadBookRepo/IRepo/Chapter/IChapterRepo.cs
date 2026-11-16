using ReadBookRepo.Base.IRepo;
using ReadBookRepo.Entity.Chapter.Dto;
using ReadBookRepo.Entity.Chapters.Entity;

namespace ReadBookRepo.IRepo.Chapters
{
    /// <summary>
    /// Kế thừa các chức năng CRUD của IMySqlBaseRepo
    /// </summary>
    public interface IChapterRepo : IMySqlBaseRepo<ChapterEntity, ChapterDto>
    {

    }
}
