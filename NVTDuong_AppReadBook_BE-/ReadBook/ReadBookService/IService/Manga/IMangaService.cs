using ReadBookRepo.Entity.Manga;
using ReadBookRepo.Entity.Manga.Dto;
using ReadBookService.Base;
///Đây là interface service, nó định nghĩa những gì MangaService cần làm.
/// chỉ là giao diện (nói rằng Service phải có GetAll()).
namespace ReadBookService.IService.Home
{
    /// <summary>
    /// Kế thừa các chức năng nghiệp vụ cơ bản từ IBaseService.
    /// </summary>
    public interface IMangaService : IBaseService<MangaEntity, MangaDto>
    {
    }
}
