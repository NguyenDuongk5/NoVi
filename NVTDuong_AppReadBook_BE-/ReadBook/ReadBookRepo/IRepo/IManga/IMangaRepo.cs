
using ReadBookRepo.Base.IRepo;
using ReadBookRepo.Entity.Manga;
using ReadBookRepo.Entity.Manga.Dto;


namespace ReadBookRepo.Repo
{
    /// <summary>
    /// Kế thừa các chức năng CRUD của IMySqlBaseRepo
    /// </summary>
    public interface IMangaRepo : IMySqlBaseRepo<MangaEntity, MangaDto>
    {

    }
}
