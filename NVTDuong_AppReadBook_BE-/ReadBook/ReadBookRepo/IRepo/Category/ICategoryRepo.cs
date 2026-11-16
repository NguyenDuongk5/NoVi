using ReadBookRepo.Base.IRepo;
using ReadBookRepo.Entity.Category;
using ReadBookRepo.Entity.Category.Dto;

namespace ReadBookRepo.IRepo.Category
{
    /// <summary>
    /// Kế thừa các chức năng CRUD của IMySqlBaseRepo
    /// </summary>
    public interface ICategoryRepo : IMySqlBaseRepo<CategoryEntity, CategoryDto>
    {
    }
}
