using ReadBookRepo.Entity.Category;
using ReadBookRepo.Entity.Category.Dto;
using ReadBookService.Base;

namespace ReadBookService.IService.Category
{
    /// <summary>
    /// Kế thừa các chức năng nghiệp vụ cơ bản từ IBaseService.
    /// </summary>
    public interface ICategoryService : IBaseService<CategoryEntity, CategoryDto> 
    {
    }
}
