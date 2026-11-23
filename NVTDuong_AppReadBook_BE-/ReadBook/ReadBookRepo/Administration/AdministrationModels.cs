namespace ReadBookRepo.Administration;

public sealed record AdminUserItem(Guid UserId, string FullName, string? DisplayName,
    string Email, sbyte Role, sbyte Status, DateTime CreatedAt);
public sealed record PagedAdminUsers(IReadOnlyList<AdminUserItem> Items, int Page,
    int PageSize, long TotalItems);
public sealed class AdminCategoryItem
{
    public Guid CategoryId { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Slug { get; init; } = string.Empty;
    public bool IsActive { get; init; }
    public long NovelCount { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
public sealed record PagedAdminCategories(IReadOnlyList<AdminCategoryItem> Items,
    int Page, int PageSize, long TotalItems);
public sealed record CategoryNameRequest(string Name);
public sealed record ActiveStatusRequest(bool Active);
public class AdminNovelItem
{
    public Guid NovelId { get; init; }
    public string Title { get; init; } = string.Empty;
    public string? CoverUrl { get; init; }
    public string AuthorName { get; init; } = string.Empty;
    public string Categories { get; init; } = string.Empty;
    public long ChapterCount { get; init; }
    public sbyte ReviewStatus { get; init; }
    public sbyte Visibility { get; init; }
    public bool HasPendingRevision { get; init; }
    public Guid? PendingRevisionId { get; init; }
    public DateTime UpdatedAt { get; init; }
}
public sealed record PagedAdminNovels(IReadOnlyList<AdminNovelItem> Items, int Page,
    int PageSize, long TotalItems);
public sealed class AdminNovelDetail : AdminNovelItem
{
    public string? OriginalAuthor { get; init; }
    public string? Description { get; init; }
    public DateTime? PublishedAt { get; init; }
    public IReadOnlyList<AdminNovelChapterItem> Chapters { get; set; } = [];
}
public class AdminNovelChapterItem
{
    public Guid ChapterId { get; init; }
    public uint ChapterNumber { get; init; }
    public string Title { get; init; } = string.Empty;
    public sbyte ReviewStatus { get; init; }
    public sbyte Visibility { get; init; }
    public bool HasPendingRevision { get; init; }
    public Guid? PendingRevisionId { get; init; }
    public DateTime UpdatedAt { get; init; }
}
public sealed class AdminNovelChapterDetail : AdminNovelChapterItem
{
    public Guid NovelId { get; init; }
    public string Content { get; init; } = string.Empty;
}
public sealed class AdministrationException(int statusCode, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}
