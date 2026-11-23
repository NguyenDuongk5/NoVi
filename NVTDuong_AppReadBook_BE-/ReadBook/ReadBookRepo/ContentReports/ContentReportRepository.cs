using Dapper;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace ReadBookRepo.ContentReports;

public sealed class ContentReportRepository(IConfiguration configuration) : IContentReportRepository
{
    private readonly string _connectionString = configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");

    public async Task<Guid> CreateAsync(Guid reporterId, CreateContentReportRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.TargetType is not (1 or 2)) throw BadRequest("Loại nội dung không hợp lệ.");
        if (request.Reason is < 1 or > 5) throw BadRequest("Vui lòng chọn lý do báo cáo.");
        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        if (description?.Length > 1000) throw BadRequest("Mô tả tối đa 1000 ký tự.");
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        var publicContent = request.TargetType == 1
            ? await connection.ExecuteScalarAsync<int?>(new CommandDefinition("""
                SELECT 1 FROM novel WHERE novel_id=@TargetId AND review_status=1
                  AND visibility=0 AND deleted_at IS NULL
                """, request, cancellationToken: cancellationToken))
            : await connection.ExecuteScalarAsync<int?>(new CommandDefinition("""
                SELECT 1 FROM chapter c JOIN novel n ON n.novel_id=c.novel_id
                WHERE c.chapter_id=@TargetId AND c.review_status=1 AND c.visibility=0
                  AND c.deleted_at IS NULL AND n.review_status=1 AND n.visibility=0 AND n.deleted_at IS NULL
                """, request, cancellationToken: cancellationToken));
        if (publicContent is null) throw new ContentReportException(404, "Nội dung không còn công khai để báo cáo.");
        var id = Guid.NewGuid();
        try
        {
            await connection.ExecuteAsync(new CommandDefinition("""
                INSERT INTO content_report(report_id,reporter_id,target_type,target_id,reason,description,status)
                VALUES(@Id,@ReporterId,@TargetType,@TargetId,@Reason,@Description,0)
                """, new { Id = id, ReporterId = reporterId, request.TargetType, request.TargetId,
                    request.Reason, Description = description }, cancellationToken: cancellationToken));
        }
        catch (MySqlException exception) when (exception.Number == 1062)
        { throw new ContentReportException(409, "Bạn đã báo cáo nội dung này và báo cáo đang chờ xử lý."); }
        return id;
    }

    public async Task<PagedContentReports> GetQueueAsync(sbyte? status, sbyte? targetType,
        int page, int pageSize, CancellationToken cancellationToken = default)
    {
        if (status is < 0 or > 2) throw BadRequest("Trạng thái không hợp lệ.");
        if (targetType is not null and not (1 or 2)) throw BadRequest("Loại nội dung không hợp lệ.");
        if (page < 1 || pageSize is < 1 or > 50) throw BadRequest("Phân trang không hợp lệ.");
        const string where = "WHERE (@Status IS NULL OR r.status=@Status) AND (@TargetType IS NULL OR r.target_type=@TargetType)";
        var args = new { Status = status, TargetType = targetType, Offset = (page - 1) * pageSize, PageSize = pageSize };
        await using var connection = new MySqlConnection(_connectionString);
        var total = await connection.ExecuteScalarAsync<long>(new CommandDefinition(
            "SELECT COUNT(*) FROM content_report r " + where, args, cancellationToken: cancellationToken));
        var items = (await connection.QueryAsync<ContentReportListItem>(new CommandDefinition("""
            SELECT r.report_id ReportId,r.target_type TargetType,r.target_id TargetId,
              CASE WHEN r.target_type=1 THEN COALESCE(n.title,'Truyện không còn tồn tại')
                   ELSE COALESCE(CONCAT('Chương ',c.chapter_number,': ',c.title),'Chương không còn tồn tại') END TargetTitle,
              CASE WHEN r.target_type=1 THEN n.description ELSE c.content END TargetContent,
              r.reason Reason,r.description Description,r.status Status,
              CASE WHEN r.target_type=1 THEN IF(n.novel_id IS NULL OR n.visibility<>0 OR n.deleted_at IS NOT NULL,1,0)
                   ELSE IF(c.chapter_id IS NULL OR c.visibility<>0 OR c.deleted_at IS NOT NULL
                     OR pn.visibility<>0 OR pn.deleted_at IS NOT NULL,1,0) END TargetUnavailable,
              r.reporter_id ReporterId,u.full_name ReporterName,u.email ReporterEmail,r.created_at CreatedAt,
              r.resolution_note ResolutionNote,r.handled_at HandledAt
            FROM content_report r JOIN `user` u ON u.user_id=r.reporter_id
            LEFT JOIN novel n ON r.target_type=1 AND n.novel_id=r.target_id
            LEFT JOIN chapter c ON r.target_type=2 AND c.chapter_id=r.target_id
            LEFT JOIN novel pn ON pn.novel_id=c.novel_id
            """ + "\n" + where + " ORDER BY r.created_at DESC,r.report_id DESC LIMIT @Offset,@PageSize",
            args, cancellationToken: cancellationToken))).AsList();
        return new(items, page, pageSize, total);
    }

    public async Task DecideAsync(Guid adminId, Guid reportId, DecideContentReportRequest request,
        CancellationToken cancellationToken = default)
    {
        var note = string.IsNullOrWhiteSpace(request.ResolutionNote) ? null : request.ResolutionNote.Trim();
        if (note?.Length > 1000) throw BadRequest("Ghi chú tối đa 1000 ký tự.");
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        var report = await connection.QuerySingleOrDefaultAsync<ReportState>(new CommandDefinition(
            "SELECT status Status,target_type TargetType,target_id TargetId FROM content_report WHERE report_id=@ReportId FOR UPDATE",
            new { ReportId = reportId }, transaction, cancellationToken: cancellationToken));
        if (report is null) throw new ContentReportException(404, "Không tìm thấy báo cáo.");
        if (report.Status != 0) throw new ContentReportException(409, "Báo cáo đã được quản trị viên khác xử lý.");
        if (request.Accept)
        {
            var table = report.TargetType == 1 ? "novel" : "chapter";
            var key = report.TargetType == 1 ? "novel_id" : "chapter_id";
            await connection.ExecuteAsync(new CommandDefinition(
                $"UPDATE {table} SET visibility=2 WHERE {key}=@TargetId AND deleted_at IS NULL",
                new { report.TargetId }, transaction, cancellationToken: cancellationToken));
        }
        await connection.ExecuteAsync(new CommandDefinition("""
            UPDATE content_report SET status=@Status,resolution_note=@Note,handled_by=@AdminId,
              handled_at=UTC_TIMESTAMP() WHERE report_id=@ReportId AND status=0
            """, new { Status = request.Accept ? 1 : 2, Note = note, AdminId = adminId, ReportId = reportId },
            transaction, cancellationToken: cancellationToken));
        await transaction.CommitAsync(cancellationToken);
    }

    private static ContentReportException BadRequest(string message) => new(400, message);
    private sealed record ReportState(sbyte Status, sbyte TargetType, Guid TargetId);
}
