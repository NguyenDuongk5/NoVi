namespace ReadBookRepo.Publishing;

public sealed record CreateAuthorApplication(string? Message);
public sealed record ModerationRequest(bool Approve, string? Reason);
public sealed record NovelWriteRequest(string Title, string? OriginalAuthor, byte SourceType,
    string? SourceUrl, string? Description, byte CompletionStatus, IReadOnlyList<Guid>? CategoryIds = null);
public sealed record ChapterWriteRequest(uint ChapterNumber, string Title, string Content);
public sealed record OwnedNovel(Guid NovelId, string Title, string Slug, string? OriginalAuthor,
    sbyte SourceType, string? SourceUrl, string? Description, string? CoverUrl, sbyte CompletionStatus,
    sbyte ReviewStatus, sbyte Visibility, string? RejectReason, DateTime UpdatedAt, DateTime? DeletedAt,
    string? CategoryIds, string? CategoryNames, Guid? RevisionId, sbyte? RevisionStatus,
    string? RevisionRejectReason, string? RevisionTitle);
public sealed record OwnedChapter(Guid ChapterId, Guid NovelId, uint ChapterNumber, string Title,
    string Content, sbyte ReviewStatus, sbyte Visibility, string? RejectReason, DateTime UpdatedAt,
    DateTime? DeletedAt, Guid? RevisionId, sbyte? RevisionStatus, string? RevisionRejectReason,
    string? RevisionTitle, string? RevisionContent);
public sealed record QueueItem(Guid Id, string TargetType, string Title, Guid SubmittedBy, DateTime SubmittedAt);
public sealed record AuthorApplicationItem(
    Guid ApplicationId,
    Guid UserId,
    string FullName,
    string Email,
    string? Message,
    sbyte Status,
    string? DecisionReason,
    DateTime CreatedAt,
    DateTime? ReviewedAt);

public sealed class ModerationDetail
{
    public Guid Id { get; set; }
    public string TargetType { get; set; } = "";
    public Guid SubmittedBy { get; set; }
    public string SubmitterName { get; set; } = "";
    public DateTime SubmittedAt { get; set; }
    public string Title { get; set; } = "";
    public string? NovelTitle { get; set; }
    public string? OriginalAuthor { get; set; }
    public sbyte? SourceType { get; set; }
    public string? SourceUrl { get; set; }
    public string? Description { get; set; }
    public string? CoverUrl { get; set; }
    public sbyte? CompletionStatus { get; set; }
    public uint? ChapterNumber { get; set; }
    public string? Content { get; set; }
    public string? CategoryNames { get; set; }
}

public sealed class PublishingException(int statusCode, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}
