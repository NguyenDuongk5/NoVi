namespace ReadBookRepo.ContentReports;

public interface IContentReportRepository
{
    Task<Guid> CreateAsync(Guid reporterId, CreateContentReportRequest request, CancellationToken cancellationToken = default);
    Task<PagedContentReports> GetQueueAsync(sbyte? status, sbyte? targetType, int page, int pageSize,
        CancellationToken cancellationToken = default);
    Task DecideAsync(Guid adminId, Guid reportId, DecideContentReportRequest request,
        CancellationToken cancellationToken = default);
}
