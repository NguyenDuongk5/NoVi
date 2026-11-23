namespace ReadBookRepo.Administration;

public interface IAdministrationRepository
{
    Task<PagedAdminUsers> GetUsersAsync(string? keyword, sbyte? role, sbyte? status,
        int page, int pageSize, CancellationToken cancellationToken = default);
    Task SetUserStatusAsync(Guid actorId, Guid userId, bool active,
        CancellationToken cancellationToken = default);
    Task<PagedAdminCategories> GetCategoriesAsync(string? keyword, int page,
        int pageSize, CancellationToken cancellationToken = default);
    Task<Guid> CreateCategoryAsync(string name, CancellationToken cancellationToken = default);
    Task UpdateCategoryAsync(Guid categoryId, string name,
        CancellationToken cancellationToken = default);
    Task SetCategoryStatusAsync(Guid categoryId, bool active,
        CancellationToken cancellationToken = default);
    Task<PagedAdminNovels> GetNovelsAsync(string? keyword, Guid? categoryId,
        sbyte? reviewStatus, sbyte? visibility, int page, int pageSize,
        CancellationToken cancellationToken = default);
    Task<AdminNovelDetail?> GetNovelAsync(Guid novelId,
        CancellationToken cancellationToken = default);
    Task<AdminNovelChapterDetail?> GetNovelChapterAsync(Guid novelId, Guid chapterId,
        CancellationToken cancellationToken = default);
    Task SetNovelVisibilityAsync(Guid novelId, bool visible,
        CancellationToken cancellationToken = default);
}
