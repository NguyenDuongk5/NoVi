using Dapper;
using MySql.Data.MySqlClient;
using ReadBookRepo.Base.Repo;
using ReadBookRepo.Entity.Category;
using ReadBookRepo.Entity.Category.Dto;
using ReadBookRepo.IRepo.Category;
namespace ReadBookRepo.Repo.Category
{
    /// <summary>
    /// Kế thừa các chức năng CRUD của MySqlBaseRepo
    /// </summary>
    public class CategoryRepo : MySqlBaseRepo<CategoryEntity, CategoryDto>, ICategoryRepo
    {
        public CategoryRepo(IConfiguration configuration) : base(configuration)
        {
        }
    }
}
