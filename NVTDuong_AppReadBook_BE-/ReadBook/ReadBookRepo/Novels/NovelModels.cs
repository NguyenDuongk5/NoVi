namespace ReadBookRepo.Novels;

public sealed record NovelListItem(Guid NovelId, string Title, string? OriginalAuthor, string? CoverUrl,
    string? Description, sbyte CompletionStatus, DateTime UpdatedAt, long ViewCount);
public sealed record NovelDetail(Guid NovelId, string Title, string? OriginalAuthor, string? CoverUrl,
    string? Description, sbyte CompletionStatus, string DisplayName, long ViewCount, long LibraryCount);
public sealed record NovelChapterItem(Guid ChapterId, uint ChapterNumber, string Title, DateTime? PublishedAt);
public sealed record PublicChapter(Guid ChapterId, Guid NovelId, uint ChapterNumber, string Title, string Content);
public sealed record PagedNovels(IReadOnlyList<NovelListItem> Items, int Page, int PageSize, long TotalItems);
public sealed record PublicCategory(Guid CategoryId, string Name, string Slug);

public enum RankingPeriod { Week, Month, All }

public sealed record RankingWindow(RankingPeriod Period, DateTime? StartUtc, DateTime EndUtc);

public sealed class RankedNovel
{
    public long Rank { get; init; }
    public Guid NovelId { get; init; }
    public string Title { get; init; } = string.Empty;
    public string? OriginalAuthor { get; init; }
    public string? CoverUrl { get; init; }
    public string? Description { get; init; }
    public sbyte CompletionStatus { get; init; }
    public long PeriodViewCount { get; init; }
    public DateTime? PublishedAt { get; init; }
    public IReadOnlyList<PublicCategory> Categories { get; set; } = [];
}

public sealed record PagedRankings(IReadOnlyList<RankedNovel> Items, string Period,
    int Page, int PageSize, long TotalItems, DateTime? PeriodStartUtc, DateTime PeriodEndUtc);
