using Dapper;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace ReadBookRepo.Novels;

public sealed class NovelRepository(IConfiguration configuration) : INovelRepository
{
    private readonly string _connectionString = configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");

    public async Task<PagedNovels> SearchPublicAsync(string? keyword, Guid? categoryId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var offset = (page - 1) * pageSize;
        const string fromWhere = """
            FROM `novel` n
            WHERE n.review_status = 1 AND n.visibility = 0 AND n.deleted_at IS NULL
              AND (@Keyword IS NULL OR MATCH(n.title, n.original_author, n.description) AGAINST(@Keyword IN NATURAL LANGUAGE MODE))
              AND (@CategoryId IS NULL OR EXISTS (
                    SELECT 1 FROM novel_category nc WHERE nc.novel_id = n.novel_id AND nc.category_id = @CategoryId))
            """;
        var parameters = new { Keyword = string.IsNullOrWhiteSpace(keyword) ? null : keyword.Trim(), CategoryId = categoryId, Offset = offset, PageSize = pageSize };
        await using var connection = new MySqlConnection(_connectionString);
        var count = await connection.ExecuteScalarAsync<long>(new CommandDefinition("SELECT COUNT(*) " + fromWhere, parameters, cancellationToken: cancellationToken));
        var sql = """
            SELECT n.novel_id AS NovelId, n.title AS Title, n.original_author AS OriginalAuthor,
                   n.cover_url AS CoverUrl, n.description AS Description,
                   n.completion_status AS CompletionStatus, n.updated_at AS UpdatedAt,
                   (SELECT COUNT(*) FROM chapter_view cv INNER JOIN chapter c ON c.chapter_id = cv.chapter_id WHERE c.novel_id = n.novel_id) AS ViewCount
            """ + "\n" + fromWhere + " ORDER BY n.updated_at DESC LIMIT @Offset, @PageSize;";
        var items = (await connection.QueryAsync<NovelListItem>(new CommandDefinition(sql, parameters, cancellationToken: cancellationToken))).AsList();
        return new PagedNovels(items, page, pageSize, count);
    }

    public async Task<NovelDetail?> GetPublicByIdAsync(Guid novelId, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT n.novel_id AS NovelId, n.title AS Title, n.original_author AS OriginalAuthor,
                   n.cover_url AS CoverUrl, n.description AS Description, n.completion_status AS CompletionStatus,
                   COALESCE(u.display_name, u.full_name) AS DisplayName,
                   (SELECT COUNT(*) FROM chapter_view cv INNER JOIN chapter c ON c.chapter_id = cv.chapter_id WHERE c.novel_id = n.novel_id) AS ViewCount,
                   (SELECT COUNT(*) FROM library_item li WHERE li.novel_id = n.novel_id) AS LibraryCount
            FROM `novel` n INNER JOIN `user` u ON u.user_id = n.uploader_id
            WHERE n.novel_id = @NovelId AND n.review_status = 1 AND n.visibility = 0 AND n.deleted_at IS NULL;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<NovelDetail>(new CommandDefinition(sql, new { NovelId = novelId }, cancellationToken: cancellationToken));
    }

    public async Task<IReadOnlyList<NovelChapterItem>> GetPublicChaptersAsync(Guid novelId, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT chapter_id AS ChapterId, chapter_number AS ChapterNumber, title AS Title, published_at AS PublishedAt
            FROM chapter WHERE novel_id = @NovelId AND review_status = 1 AND visibility = 0 AND deleted_at IS NULL
            ORDER BY chapter_number;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        return (await connection.QueryAsync<NovelChapterItem>(new CommandDefinition(sql, new { NovelId = novelId }, cancellationToken: cancellationToken))).AsList();
    }

    public async Task<PublicChapter?> GetPublicChapterAsync(Guid chapterId, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT c.chapter_id AS ChapterId, c.novel_id AS NovelId, c.chapter_number AS ChapterNumber,
                   c.title AS Title, c.content AS Content
            FROM chapter c INNER JOIN `novel` n ON n.novel_id = c.novel_id
            WHERE c.chapter_id = @ChapterId AND c.review_status = 1 AND c.visibility = 0 AND c.deleted_at IS NULL
              AND n.review_status = 1 AND n.visibility = 0 AND n.deleted_at IS NULL;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<PublicChapter>(new CommandDefinition(sql, new { ChapterId = chapterId }, cancellationToken: cancellationToken));
    }

    public async Task<IReadOnlyList<PublicCategory>> GetActiveCategoriesAsync(CancellationToken cancellationToken = default)
    {
        const string sql = "SELECT category_id AS CategoryId, name AS Name, slug AS Slug FROM category WHERE is_active = 1 ORDER BY name;";
        await using var connection = new MySqlConnection(_connectionString);
        return (await connection.QueryAsync<PublicCategory>(new CommandDefinition(sql, cancellationToken: cancellationToken))).AsList();
    }

    public async Task<PagedRankings> GetRankingsAsync(RankingPeriod period, Guid? categoryId,
        bool completedOnly, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var window = RankingPeriodResolver.Resolve(period, DateTime.UtcNow);
        var offset = (page - 1) * pageSize;
        const string filters = """
            n.review_status = 1 AND n.visibility = 0 AND n.deleted_at IS NULL
            AND c.review_status = 1 AND c.visibility = 0 AND c.deleted_at IS NULL
            AND (@StartUtc IS NULL OR cv.viewed_at >= @StartUtc) AND cv.viewed_at < @EndUtc
            AND (@CompletedOnly = 0 OR n.completion_status = 1)
            AND (@CategoryId IS NULL OR EXISTS (
                SELECT 1 FROM novel_category selected_nc
                WHERE selected_nc.novel_id = n.novel_id AND selected_nc.category_id = @CategoryId))
            """;
        var parameters = new
        {
            window.StartUtc,
            window.EndUtc,
            CategoryId = categoryId,
            CompletedOnly = completedOnly ? 1 : 0,
            Offset = offset,
            PageSize = pageSize
        };
        var aggregate = """
            SELECT n.novel_id, n.title, n.original_author, n.cover_url, n.description,
                   n.completion_status, n.published_at, COUNT(*) AS period_view_count
            FROM novel n
            INNER JOIN chapter c ON c.novel_id = n.novel_id
            INNER JOIN chapter_view cv ON cv.chapter_id = c.chapter_id
            WHERE 
            """ + filters + " GROUP BY n.novel_id, n.title, n.original_author, n.cover_url, n.description, n.completion_status, n.published_at";
        var countSql = "SELECT COUNT(*) FROM (" + aggregate + ") ranking_count;";
        var pageSql = """
            WITH aggregated AS (
            """ + aggregate + """
            )
            SELECT ROW_NUMBER() OVER (
                       ORDER BY period_view_count DESC, published_at IS NULL ASC, published_at ASC, novel_id ASC) AS `Rank`,
                   novel_id AS NovelId, title AS Title, original_author AS OriginalAuthor,
                   cover_url AS CoverUrl, description AS Description,
                   completion_status AS CompletionStatus, period_view_count AS PeriodViewCount,
                   published_at AS PublishedAt
            FROM aggregated
            ORDER BY period_view_count DESC, published_at IS NULL ASC, published_at ASC, novel_id ASC
            LIMIT @Offset, @PageSize;
            """;

        await using var connection = new MySqlConnection(_connectionString);
        var total = await connection.ExecuteScalarAsync<long>(new CommandDefinition(
            countSql, parameters, cancellationToken: cancellationToken));
        var items = (await connection.QueryAsync<RankedNovel>(new CommandDefinition(
            pageSql, parameters, cancellationToken: cancellationToken))).AsList();

        if (items.Count > 0)
        {
            const string categorySql = """
                SELECT nc.novel_id AS NovelId, cat.category_id AS CategoryId,
                       cat.name AS Name, cat.slug AS Slug
                FROM novel_category nc
                INNER JOIN category cat ON cat.category_id = nc.category_id
                WHERE nc.novel_id IN @NovelIds AND cat.is_active = 1
                ORDER BY cat.name;
                """;
            var categoryRows = await connection.QueryAsync<RankingCategoryRow>(new CommandDefinition(
                categorySql, new { NovelIds = items.Select(x => x.NovelId).ToArray() },
                cancellationToken: cancellationToken));
            var byNovel = categoryRows.GroupBy(x => x.NovelId).ToDictionary(
                x => x.Key,
                x => (IReadOnlyList<PublicCategory>)x.Select(c =>
                    new PublicCategory(c.CategoryId, c.Name, c.Slug)).ToList());
            foreach (var item in items)
                item.Categories = byNovel.GetValueOrDefault(item.NovelId) ?? [];
        }

        return new PagedRankings(items, period.ToString().ToLowerInvariant(), page, pageSize, total,
            window.StartUtc, window.EndUtc);
    }

    private sealed record RankingCategoryRow(Guid NovelId, Guid CategoryId, string Name, string Slug);
}

public static class RankingPeriodResolver
{
    private static readonly TimeZoneInfo VietnamTimeZone = FindVietnamTimeZone();

    public static RankingWindow Resolve(RankingPeriod period, DateTime utcNow)
    {
        utcNow = DateTime.SpecifyKind(utcNow, DateTimeKind.Utc);
        if (period == RankingPeriod.All) return new(period, null, utcNow);

        var localNow = TimeZoneInfo.ConvertTimeFromUtc(utcNow, VietnamTimeZone);
        DateTime localStart;
        if (period == RankingPeriod.Month)
            localStart = new DateTime(localNow.Year, localNow.Month, 1);
        else
        {
            var daysFromMonday = ((int)localNow.DayOfWeek + 6) % 7;
            localStart = localNow.Date.AddDays(-daysFromMonday);
        }
        return new(period, TimeZoneInfo.ConvertTimeToUtc(localStart, VietnamTimeZone), utcNow);
    }

    private static TimeZoneInfo FindVietnamTimeZone()
    {
        foreach (var id in new[] { "Asia/Ho_Chi_Minh", "SE Asia Standard Time" })
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); } catch (TimeZoneNotFoundException) { }
        throw new InvalidOperationException("Vietnam time zone is unavailable on this host.");
    }
}
