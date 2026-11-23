namespace ReadBookRepo.ContentReports;

public sealed record CreateContentReportRequest(sbyte TargetType, Guid TargetId, sbyte Reason, string? Description);
public sealed record DecideContentReportRequest(bool Accept, string? ResolutionNote);
public sealed class ContentReportListItem
{
    public Guid ReportId { get; init; }
    public sbyte TargetType { get; init; }
    public Guid TargetId { get; init; }
    public string TargetTitle { get; init; } = string.Empty;
    public string? TargetContent { get; init; }
    public sbyte Reason { get; init; }
    public string? Description { get; init; }
    public sbyte Status { get; init; }
    public bool TargetUnavailable { get; init; }
    public Guid ReporterId { get; init; }
    public string ReporterName { get; init; } = string.Empty;
    public string ReporterEmail { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public string? ResolutionNote { get; init; }
    public DateTime? HandledAt { get; init; }
}
public sealed record PagedContentReports(IReadOnlyList<ContentReportListItem> Items,
    int Page, int PageSize, long TotalItems);

public sealed class ContentReportException(int statusCode, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}
