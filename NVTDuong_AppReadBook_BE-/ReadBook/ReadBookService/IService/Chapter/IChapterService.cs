using ReadBookRepo.Entity.Chapter.Dto;
using ReadBookRepo.Entity.Chapters.Entity;
using ReadBookService.Base;

namespace ReadBookService.IService.Chapters
{
    /// <summary>
    /// Kế thừa các chức năng nghiệp vụ cơ bản từ IBaseService.
    /// </summary>
    public interface IChapterService : IBaseService<ChapterEntity, ChapterDto>
    {

    }
}
