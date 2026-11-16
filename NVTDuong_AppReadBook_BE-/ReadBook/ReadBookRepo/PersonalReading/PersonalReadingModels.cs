namespace ReadBookRepo.PersonalReading;

public sealed record LibraryNovel(Guid NovelId,string Title,string? CoverUrl,string? OriginalAuthor,string? Description,sbyte CompletionStatus,DateTime SavedAt,DateTime UpdatedAt);
public sealed record PagedLibrary(IReadOnlyList<LibraryNovel> Items,int Page,int PageSize,long TotalItems);
public sealed record ReadSessionResult(Guid SessionId,DateTime StartedAt);
public sealed record ProgressRequest(Guid SessionId,long Sequence,decimal PositionPercent);
public sealed class ReadingProgressResult
{
    public Guid NovelId{get;init;} public Guid ChapterId{get;init;} public uint ChapterNumber{get;init;}
    public string ChapterTitle{get;init;}=string.Empty; public decimal PositionPercent{get;init;}
    public DateTime UpdatedAt{get;init;} public bool Available{get;init;}
}
public sealed record ViewResult(bool Counted,int WindowMinutes);
public sealed class HistoryItem{public long HistoryId{get;init;}public Guid NovelId{get;init;}public string NovelTitle{get;init;}=string.Empty;public Guid ChapterId{get;init;}public uint ChapterNumber{get;init;}public string ChapterTitle{get;init;}=string.Empty;public DateTime ReadAt{get;init;}public bool Available{get;init;}}
public sealed record PagedHistory(IReadOnlyList<HistoryItem> Items,int Page,int PageSize,long TotalItems);

public interface IPersonalReadingRepository
{
    Task SaveAsync(Guid userId,Guid novelId,CancellationToken ct=default);
    Task RemoveAsync(Guid userId,Guid novelId,CancellationToken ct=default);
    Task<PagedLibrary> ListAsync(Guid userId,int page,int pageSize,string sort,CancellationToken ct=default);
    Task<ReadSessionResult> BeginAsync(Guid userId,Guid novelId,Guid chapterId,CancellationToken ct=default);
    Task<ReadingProgressResult> UpdateProgressAsync(Guid userId,Guid novelId,Guid chapterId,ProgressRequest request,CancellationToken ct=default);
    Task<ReadingProgressResult?> ContinueAsync(Guid userId,Guid novelId,CancellationToken ct=default);
    Task<ViewResult> RecordViewAsync(Guid userId,Guid novelId,Guid chapterId,int windowMinutes,CancellationToken ct=default);
    Task<PagedHistory> HistoryAsync(Guid userId,int page,int pageSize,CancellationToken ct=default);
}
