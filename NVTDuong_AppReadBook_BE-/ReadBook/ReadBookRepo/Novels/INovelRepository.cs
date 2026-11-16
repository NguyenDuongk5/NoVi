namespace ReadBookRepo.Novels;

public interface INovelRepository
{
    Task<PagedNovels> SearchPublicAsync(string? keyword, Guid? categoryId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<NovelDetail?> GetPublicByIdAsync(Guid novelId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<NovelChapterItem>> GetPublicChaptersAsync(Guid novelId, CancellationToken cancellationToken = default);
    Task<PublicChapter?> GetPublicChapterAsync(Guid chapterId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PublicCategory>> GetActiveCategoriesAsync(CancellationToken cancellationToken = default);
    Task<PagedRankings> GetRankingsAsync(RankingPeriod period, Guid? categoryId, bool completedOnly,
        int page, int pageSize, CancellationToken cancellationToken = default);
}
