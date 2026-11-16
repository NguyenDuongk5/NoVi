namespace ReadBookRepo.Media;
public sealed record CoverUpdateResult(Guid? RevisionId, bool PendingApproval);
public interface IMediaRepository
{
    Task EnsureActiveUserAsync(Guid userId,CancellationToken ct=default);
    Task UpdateAvatarAsync(Guid userId,string url,CancellationToken ct=default);
    Task EnsureOwnedNovelAsync(Guid userId,Guid novelId,CancellationToken ct=default);
    Task<CoverUpdateResult> SetCoverAsync(Guid userId,Guid novelId,string url,CancellationToken ct=default);
    Task<HashSet<string>> GetReferencedMediaUrlsAsync(CancellationToken ct=default);
}
