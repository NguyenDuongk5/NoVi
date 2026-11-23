using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace ReadBookRepo.Administration;

public sealed class AdministrationRepository(IConfiguration configuration) : IAdministrationRepository
{
    private readonly string _connectionString = configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");

    public async Task<PagedAdminUsers> GetUsersAsync(string? keyword, sbyte? role,
        sbyte? status, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        if (role is < 0 or > 2) throw BadRequest("Vai trò không hợp lệ.");
        if (status is < 0 or > 1) throw BadRequest("Trạng thái không hợp lệ.");
        const string where = """
            WHERE (@Keyword IS NULL OR u.full_name LIKE CONCAT('%',@Keyword,'%')
                   OR u.display_name LIKE CONCAT('%',@Keyword,'%') OR u.email LIKE CONCAT('%',@Keyword,'%'))
              AND (@Role IS NULL OR u.role=@Role) AND (@Status IS NULL OR u.status=@Status)
            """;
        var args = new { Keyword = string.IsNullOrWhiteSpace(keyword) ? null : keyword.Trim(),
            Role = role, Status = status, Offset = (page - 1) * pageSize, PageSize = pageSize };
        await using var connection = new MySqlConnection(_connectionString);
        var total = await connection.ExecuteScalarAsync<long>(new CommandDefinition(
            "SELECT COUNT(*) FROM `user` u\n" + where, args, cancellationToken: cancellationToken));
        var items = (await connection.QueryAsync<AdminUserItem>(new CommandDefinition("""
            SELECT u.user_id UserId,u.full_name FullName,u.display_name DisplayName,
                   u.email Email,u.role Role,u.status Status,u.created_at CreatedAt
            FROM `user` u
            """ + "\n" + where + "\nORDER BY u.created_at DESC,u.user_id LIMIT @Offset,@PageSize",
            args, cancellationToken: cancellationToken))).AsList();
        return new(items, page, pageSize, total);
    }

    public async Task SetUserStatusAsync(Guid actorId, Guid userId, bool active,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        var target = await connection.QuerySingleOrDefaultAsync<UserState>(
            new CommandDefinition("SELECT role Role,status Status FROM `user` WHERE user_id=@UserId FOR UPDATE",
                new { UserId = userId }, transaction, cancellationToken: cancellationToken));
        if (target is null) throw new AdministrationException(404, "Không tìm thấy tài khoản.");
        if (userId == actorId || target.Role == 2)
            throw new AdministrationException(409, "Không thể thay đổi trạng thái tài khoản quản trị viên.");
        var status = active ? 1 : 0;
        if (target.Status != status)
            await connection.ExecuteAsync(new CommandDefinition("""
                UPDATE `user` SET status=@Status,locked_at=IF(@Status=0,UTC_TIMESTAMP(),NULL),
                    lock_reason=IF(@Status=0,'Khóa bởi quản trị viên',NULL)
                WHERE user_id=@UserId
                """, new { Status = status, UserId = userId }, transaction,
                cancellationToken: cancellationToken));
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<PagedAdminCategories> GetCategoriesAsync(string? keyword, int page,
        int pageSize, CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string where = "WHERE (@Keyword IS NULL OR c.name LIKE CONCAT('%',@Keyword,'%'))";
        var args = new { Keyword = string.IsNullOrWhiteSpace(keyword) ? null : keyword.Trim(),
            Offset = (page - 1) * pageSize, PageSize = pageSize };
        await using var connection = new MySqlConnection(_connectionString);
        var total = await connection.ExecuteScalarAsync<long>(new CommandDefinition(
            "SELECT COUNT(*) FROM category c\n" + where, args, cancellationToken: cancellationToken));
        var items = (await connection.QueryAsync<AdminCategoryItem>(new CommandDefinition("""
            SELECT c.category_id CategoryId,c.name Name,c.slug Slug,c.is_active IsActive,
                   COUNT(nc.novel_id) NovelCount,c.created_at CreatedAt,c.updated_at UpdatedAt
            FROM category c LEFT JOIN novel_category nc ON nc.category_id=c.category_id
            """ + "\n" + where + "\nGROUP BY c.category_id,c.name,c.slug,c.is_active,c.created_at,c.updated_at " +
            "ORDER BY c.name,c.category_id LIMIT @Offset,@PageSize", args,
            cancellationToken: cancellationToken))).AsList();
        return new(items, page, pageSize, total);
    }

    public async Task<Guid> CreateCategoryAsync(string name,
        CancellationToken cancellationToken = default)
    {
        name = ValidateName(name); var id = Guid.NewGuid(); var slug = Slug(name);
        await using var connection = new MySqlConnection(_connectionString);
        try
        {
            await connection.ExecuteAsync(new CommandDefinition(
                "INSERT INTO category(category_id,name,slug,is_active) VALUES(@Id,@Name,@Slug,1)",
                new { Id = id, Name = name, Slug = slug }, cancellationToken: cancellationToken));
        }
        catch (MySqlException exception) when (exception.Number == 1062)
        { throw new AdministrationException(409, "Thể loại đã tồn tại."); }
        return id;
    }

    public async Task UpdateCategoryAsync(Guid categoryId, string name,
        CancellationToken cancellationToken = default)
    {
        name = ValidateName(name); var slug = Slug(name);
        await using var connection = new MySqlConnection(_connectionString);
        try
        {
            var exists = await connection.ExecuteScalarAsync<bool>(new CommandDefinition(
                "SELECT EXISTS(SELECT 1 FROM category WHERE category_id=@CategoryId)",
                new { CategoryId = categoryId }, cancellationToken: cancellationToken));
            if (!exists) throw new AdministrationException(404, "Không tìm thấy thể loại.");
            await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE category SET name=@Name,slug=@Slug WHERE category_id=@CategoryId",
                new { Name = name, Slug = slug, CategoryId = categoryId }, cancellationToken: cancellationToken));
        }
        catch (MySqlException exception) when (exception.Number == 1062)
        { throw new AdministrationException(409, "Thể loại đã tồn tại."); }
    }

    public async Task SetCategoryStatusAsync(Guid categoryId, bool active,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new MySqlConnection(_connectionString);
        var exists = await connection.ExecuteScalarAsync<bool>(new CommandDefinition(
            "SELECT EXISTS(SELECT 1 FROM category WHERE category_id=@CategoryId)",
            new { CategoryId = categoryId }, cancellationToken: cancellationToken));
        if (!exists) throw new AdministrationException(404, "Không tìm thấy thể loại.");
        await connection.ExecuteAsync(new CommandDefinition(
            "UPDATE category SET is_active=@Active WHERE category_id=@CategoryId",
            new { Active = active ? 1 : 0, CategoryId = categoryId }, cancellationToken: cancellationToken));
    }

    public async Task<PagedAdminNovels> GetNovelsAsync(string? keyword, Guid? categoryId,
        sbyte? reviewStatus, sbyte? visibility, int page, int pageSize,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        if (reviewStatus is < 0 or > 2) throw BadRequest("Trạng thái duyệt không hợp lệ.");
        if (visibility is < 0 or > 2) throw BadRequest("Trạng thái hiển thị không hợp lệ.");
        const string where = """
            WHERE n.deleted_at IS NULL
              AND (@Keyword IS NULL OR n.title LIKE CONCAT('%',@Keyword,'%')
                   OR n.original_author LIKE CONCAT('%',@Keyword,'%')
                   OR u.full_name LIKE CONCAT('%',@Keyword,'%')
                   OR u.display_name LIKE CONCAT('%',@Keyword,'%'))
              AND (@CategoryId IS NULL OR EXISTS(SELECT 1 FROM novel_category f WHERE f.novel_id=n.novel_id AND f.category_id=@CategoryId))
              AND (@ReviewStatus IS NULL OR n.review_status=@ReviewStatus)
              AND (@Visibility IS NULL OR n.visibility=@Visibility)
            """;
        var args = new { Keyword = string.IsNullOrWhiteSpace(keyword) ? null : keyword.Trim(),
            CategoryId = categoryId, ReviewStatus = reviewStatus, Visibility = visibility,
            Offset = (page - 1) * pageSize, PageSize = pageSize };
        await using var connection = new MySqlConnection(_connectionString);
        var total = await connection.ExecuteScalarAsync<long>(new CommandDefinition(
            "SELECT COUNT(*) FROM novel n JOIN `user` u ON u.user_id=n.uploader_id\n" + where,
            args, cancellationToken: cancellationToken));
        var items = (await connection.QueryAsync<AdminNovelItem>(new CommandDefinition("""
            SELECT n.novel_id NovelId,n.title Title,n.cover_url CoverUrl,
                   COALESCE(u.display_name,u.full_name) AuthorName,
                   COALESCE((SELECT GROUP_CONCAT(c.name ORDER BY c.name SEPARATOR ', ')
                     FROM novel_category nc JOIN category c ON c.category_id=nc.category_id
                     WHERE nc.novel_id=n.novel_id),'') Categories,
                   (SELECT COUNT(*) FROM chapter ch WHERE ch.novel_id=n.novel_id AND ch.deleted_at IS NULL) ChapterCount,
                   n.review_status ReviewStatus,n.visibility Visibility,
                   EXISTS(SELECT 1 FROM novel_revision nr WHERE nr.novel_id=n.novel_id AND nr.review_status=0) HasPendingRevision,
                   (SELECT nr.revision_id FROM novel_revision nr WHERE nr.novel_id=n.novel_id AND nr.review_status=0 LIMIT 1) PendingRevisionId,
                   n.updated_at UpdatedAt
            FROM novel n JOIN `user` u ON u.user_id=n.uploader_id
            """ + "\n" + where + "\nORDER BY n.updated_at DESC,n.novel_id LIMIT @Offset,@PageSize",
            args, cancellationToken: cancellationToken))).AsList();
        return new(items, page, pageSize, total);
    }

    public async Task<AdminNovelDetail?> GetNovelAsync(Guid novelId,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new MySqlConnection(_connectionString);
        var item = await connection.QuerySingleOrDefaultAsync<AdminNovelDetail>(new CommandDefinition("""
            SELECT n.novel_id NovelId,n.title Title,n.cover_url CoverUrl,
                   COALESCE(u.display_name,u.full_name) AuthorName,n.original_author OriginalAuthor,
                   n.description Description,n.published_at PublishedAt,
                   COALESCE((SELECT GROUP_CONCAT(c.name ORDER BY c.name SEPARATOR ', ')
                     FROM novel_category nc JOIN category c ON c.category_id=nc.category_id
                     WHERE nc.novel_id=n.novel_id),'') Categories,
                   (SELECT COUNT(*) FROM chapter ch WHERE ch.novel_id=n.novel_id AND ch.deleted_at IS NULL) ChapterCount,
                   n.review_status ReviewStatus,n.visibility Visibility,
                   EXISTS(SELECT 1 FROM novel_revision nr WHERE nr.novel_id=n.novel_id AND nr.review_status=0) HasPendingRevision,
                   (SELECT nr.revision_id FROM novel_revision nr WHERE nr.novel_id=n.novel_id AND nr.review_status=0 LIMIT 1) PendingRevisionId,
                   n.updated_at UpdatedAt
            FROM novel n JOIN `user` u ON u.user_id=n.uploader_id
            WHERE n.novel_id=@NovelId AND n.deleted_at IS NULL
            """, new { NovelId = novelId }, cancellationToken: cancellationToken));
        if (item is null) return null;
        var chapterRows = await connection.QueryAsync<AdminNovelChapterRow>(new CommandDefinition("""
            SELECT ch.chapter_id ChapterId,ch.chapter_number ChapterNumber,ch.title Title,
                   ch.review_status ReviewStatus,ch.visibility Visibility,
                   CAST(EXISTS(SELECT 1 FROM chapter_revision cr WHERE cr.chapter_id=ch.chapter_id AND cr.review_status=0) AS UNSIGNED) HasPendingRevision,
                   (SELECT cr.revision_id FROM chapter_revision cr WHERE cr.chapter_id=ch.chapter_id AND cr.review_status=0 LIMIT 1) PendingRevisionId,
                   ch.updated_at UpdatedAt
            FROM chapter ch WHERE ch.novel_id=@NovelId AND ch.deleted_at IS NULL
            ORDER BY ch.chapter_number,ch.chapter_id
            """, new { NovelId = novelId }, cancellationToken: cancellationToken));
        item.Chapters = chapterRows.Select(row => new AdminNovelChapterItem
        {
            ChapterId = row.ChapterId,
            ChapterNumber = checked((uint)row.ChapterNumber),
            Title = row.Title,
            ReviewStatus = row.ReviewStatus,
            Visibility = row.Visibility,
            HasPendingRevision = row.HasPendingRevision != 0,
            PendingRevisionId = row.PendingRevisionId,
            UpdatedAt = row.UpdatedAt
        }).ToList();
        return item;
    }

    public async Task<AdminNovelChapterDetail?> GetNovelChapterAsync(Guid novelId, Guid chapterId,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new MySqlConnection(_connectionString);
        var row = await connection.QuerySingleOrDefaultAsync<AdminNovelChapterDetailRow>(
            new CommandDefinition("""
                SELECT ch.chapter_id ChapterId,ch.novel_id NovelId,
                       ch.chapter_number ChapterNumber,ch.title Title,ch.content Content,
                       ch.review_status ReviewStatus,ch.visibility Visibility,
                       CAST(EXISTS(SELECT 1 FROM chapter_revision cr
                         WHERE cr.chapter_id=ch.chapter_id AND cr.review_status=0) AS UNSIGNED) HasPendingRevision,
                       (SELECT cr.revision_id FROM chapter_revision cr
                         WHERE cr.chapter_id=ch.chapter_id AND cr.review_status=0 LIMIT 1) PendingRevisionId,
                       ch.updated_at UpdatedAt
                FROM chapter ch
                JOIN novel n ON n.novel_id=ch.novel_id
                WHERE ch.chapter_id=@ChapterId AND ch.novel_id=@NovelId
                  AND ch.deleted_at IS NULL AND n.deleted_at IS NULL
                """, new { NovelId = novelId, ChapterId = chapterId },
                cancellationToken: cancellationToken));
        if (row is null) return null;
        return new AdminNovelChapterDetail
        {
            ChapterId = row.ChapterId,
            NovelId = row.NovelId,
            ChapterNumber = checked((uint)row.ChapterNumber),
            Title = row.Title,
            Content = row.Content,
            ReviewStatus = row.ReviewStatus,
            Visibility = row.Visibility,
            HasPendingRevision = row.HasPendingRevision != 0,
            PendingRevisionId = row.PendingRevisionId,
            UpdatedAt = row.UpdatedAt
        };
    }

    public async Task SetNovelVisibilityAsync(Guid novelId, bool visible,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        var state = await connection.QuerySingleOrDefaultAsync<NovelState>(new CommandDefinition(
            "SELECT review_status ReviewStatus,visibility Visibility,deleted_at DeletedAt FROM novel WHERE novel_id=@NovelId FOR UPDATE",
            new { NovelId = novelId }, transaction, cancellationToken: cancellationToken));
        if (state is null || state.DeletedAt is not null) throw new AdministrationException(404, "Không tìm thấy truyện.");
        if (visible && state.ReviewStatus != 1)
            throw new AdministrationException(409, "Chỉ có thể hiện lại truyện đã được duyệt.");
        await connection.ExecuteAsync(new CommandDefinition(
            "UPDATE novel SET visibility=@Visibility WHERE novel_id=@NovelId",
            new { Visibility = visible ? 0 : 2, NovelId = novelId }, transaction,
            cancellationToken: cancellationToken));
        await transaction.CommitAsync(cancellationToken);
    }

    private static string ValidateName(string? name)
    {
        name = name?.Trim();
        if (string.IsNullOrWhiteSpace(name)) throw BadRequest("Vui lòng nhập tên thể loại.");
        if (name.Length > 100) throw BadRequest("Tên thể loại không được vượt quá 100 ký tự.");
        return name;
    }
    private static AdministrationException BadRequest(string message) => new(400, message);
    private static string Slug(string value)
    {
        var normalized = value.Replace('đ', 'd').Replace('Đ', 'D').Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder();
        foreach (var character in normalized)
            if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark)
                builder.Append(char.ToLowerInvariant(character));
        return Regex.Replace(Regex.Replace(builder.ToString(), "[^a-z0-9]+", "-"), "(^-|-$)", "");
    }
    private sealed class UserState
    {
        public sbyte Role { get; init; }
        public sbyte Status { get; init; }
    }
    private sealed class NovelState
    {
        public sbyte ReviewStatus { get; init; }
        public sbyte Visibility { get; init; }
        public DateTime? DeletedAt { get; init; }
    }
    private class AdminNovelChapterRow
    {
        public Guid ChapterId { get; init; }
        public ulong ChapterNumber { get; init; }
        public string Title { get; init; } = string.Empty;
        public sbyte ReviewStatus { get; init; }
        public sbyte Visibility { get; init; }
        public ulong HasPendingRevision { get; init; }
        public Guid? PendingRevisionId { get; init; }
        public DateTime UpdatedAt { get; init; }
    }
    private sealed class AdminNovelChapterDetailRow : AdminNovelChapterRow
    {
        public Guid NovelId { get; init; }
        public string Content { get; init; } = string.Empty;
    }
}
