namespace ReadBookRepo.Publishing;

public sealed record CreateAuthorApplication(string? Message);
public sealed record ModerationRequest(bool Approve, string? Reason);
public sealed record NovelWriteRequest(string Title, string? OriginalAuthor, byte SourceType,
    string? SourceUrl, string? Description, byte CompletionStatus);
public sealed record ChapterWriteRequest(uint ChapterNumber, string Title, string Content);
public sealed record OwnedNovel(Guid NovelId, string Title, string Slug, sbyte ReviewStatus,
    sbyte Visibility, string? RejectReason, DateTime UpdatedAt, DateTime? DeletedAt);
public sealed record OwnedChapter(Guid ChapterId, Guid NovelId, uint ChapterNumber, string Title,
    sbyte ReviewStatus, sbyte Visibility, string? RejectReason, DateTime UpdatedAt, DateTime? DeletedAt);
public sealed record QueueItem(Guid Id, string TargetType, string Title, Guid SubmittedBy, DateTime SubmittedAt);

public sealed class PublishingException(int statusCode, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}
