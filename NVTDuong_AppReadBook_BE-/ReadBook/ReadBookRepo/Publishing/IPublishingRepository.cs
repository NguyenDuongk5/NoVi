namespace ReadBookRepo.Publishing;

public interface IPublishingRepository
{
    Task<Guid> ApplyForAuthorAsync(Guid userId, CreateAuthorApplication request, CancellationToken ct = default);
    Task<IReadOnlyList<QueueItem>> GetAuthorApplicationsAsync(CancellationToken ct = default);
    Task DecideAuthorApplicationAsync(Guid adminId, Guid applicationId, ModerationRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<OwnedNovel>> GetMyNovelsAsync(Guid userId, CancellationToken ct = default);
    Task<OwnedNovel?> GetMyNovelAsync(Guid userId, Guid novelId, CancellationToken ct = default);
    Task<Guid> CreateNovelAsync(Guid userId, NovelWriteRequest request, CancellationToken ct = default);
    Task<Guid?> UpdateNovelAsync(Guid userId, Guid novelId, NovelWriteRequest request, CancellationToken ct = default);
    Task SetNovelVisibilityAsync(Guid userId, Guid novelId, bool visible, CancellationToken ct = default);
    Task SoftDeleteNovelAsync(Guid userId, Guid novelId, CancellationToken ct = default);
    Task<IReadOnlyList<OwnedChapter>> GetMyChaptersAsync(Guid userId, Guid novelId, CancellationToken ct = default);
    Task<Guid> CreateChapterAsync(Guid userId, Guid novelId, ChapterWriteRequest request, CancellationToken ct = default);
    Task<Guid?> UpdateChapterAsync(Guid userId, Guid chapterId, ChapterWriteRequest request, CancellationToken ct = default);
    Task SetChapterVisibilityAsync(Guid userId, Guid chapterId, bool visible, CancellationToken ct = default);
    Task SoftDeleteChapterAsync(Guid userId, Guid chapterId, CancellationToken ct = default);
    Task<IReadOnlyList<QueueItem>> GetModerationQueueAsync(CancellationToken ct = default);
    Task DecideAsync(Guid adminId, string targetType, Guid targetId, ModerationRequest request, CancellationToken ct = default);
}
