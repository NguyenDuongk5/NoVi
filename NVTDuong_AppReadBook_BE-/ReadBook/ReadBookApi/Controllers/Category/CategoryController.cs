using Microsoft.AspNetCore.Mvc;
using ReadBookRepo.Entity.Category;
using ReadBookRepo.Entity.Category.Dto;
using ReadBookService.IService.Category;

namespace ReadBookApi.Controllers.Category
{
    [ApiController]
    [Route("[controller]")]

    /// <summary>
    /// Controller xử lý các API liên quan đến danh mục (Category).
    /// Kế thừa BaseController để sử dụng các chức năng CRUD chung.
    /// </summary>
    public class CategoryController : BaseController<CategoryEntity, CategoryDto>
    {   
        private readonly ICategoryService _repo;

        public CategoryController(ICategoryService baseRepo)
            : base(baseRepo)
        {
            _repo = baseRepo;
        }


    }
}
