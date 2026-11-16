using ReadBookRepo.Base.IRepo;
using ReadBookRepo.Entity.Category;
using ReadBookRepo.Entity.Category.Dto;
using ReadBookService.IService.Category;
using ReadBookService.Service.Base;

namespace ReadBookService.Service.Category
{
    /// <summary>
    /// Kế thừa BaseService để sử dụng các chức năng chung
    /// </summary>
    public class CategoryService : BaseService<CategoryEntity, CategoryDto>, ICategoryService
    {
        private readonly IMySqlBaseRepo<CategoryEntity, CategoryDto> _repo;

        /// <summary>
        /// Khởi tạo service
        /// </summary>
        /// <param name="baseRepo"></param>
        public CategoryService(IMySqlBaseRepo<CategoryEntity, CategoryDto> baseRepo)
            : base(baseRepo)
        {
            _repo = baseRepo;
        }
    }
}
