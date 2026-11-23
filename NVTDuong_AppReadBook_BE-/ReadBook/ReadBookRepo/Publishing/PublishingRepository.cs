using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace ReadBookRepo.Publishing;

public sealed partial class PublishingRepository(IConfiguration configuration) : IPublishingRepository
{
    private readonly string _cs = configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");

    public async Task<Guid> ApplyForAuthorAsync(Guid userId, CreateAuthorApplication request, CancellationToken ct = default)
    {
        await using var c = await OpenAsync(ct);
        await RequireUserAsync(c, userId, 0, ct);
        var id = Guid.NewGuid();
        try
        {
            await c.ExecuteAsync(Cmd("INSERT INTO author_application(application_id,user_id,message) VALUES(@Id,@UserId,@Message)", new { Id=id, UserId=userId, request.Message }, ct));
        }
        catch (MySqlException e) when (e.Number == 1062) { throw Conflict("Bạn đã có yêu cầu nâng quyền đang chờ duyệt."); }
        return id;
    }

    public async Task<AuthorApplicationItem?> GetMyAuthorApplicationAsync(Guid userId, CancellationToken ct = default)
    {
        const string sql = """
            SELECT a.application_id ApplicationId,a.user_id UserId,u.full_name FullName,u.email Email,
                   a.message Message,a.status Status,a.decision_reason DecisionReason,
                   a.created_at CreatedAt,a.reviewed_at ReviewedAt
            FROM author_application a JOIN `user` u ON u.user_id=a.user_id
            WHERE a.user_id=@UserId AND u.status=1
            ORDER BY a.created_at DESC LIMIT 1
            """;
        await using var c = await OpenAsync(ct);
        var active = await c.ExecuteScalarAsync<bool>(Cmd(
            "SELECT EXISTS(SELECT 1 FROM `user` WHERE user_id=@UserId AND status=1)",
            new { UserId=userId },ct));
        if(!active) throw Forbidden("Tài khoản đang bị khóa hoặc không tồn tại.");
        return await c.QuerySingleOrDefaultAsync<AuthorApplicationItem>(Cmd(sql,new { UserId=userId },ct));
    }

    public async Task<IReadOnlyList<AuthorApplicationItem>> GetAuthorApplicationsAsync(CancellationToken ct = default)
    {
        const string sql = """
            SELECT a.application_id ApplicationId,a.user_id UserId,u.full_name FullName,u.email Email,
                   a.message Message,a.status Status,a.decision_reason DecisionReason,
                   a.created_at CreatedAt,a.reviewed_at ReviewedAt
            FROM author_application a JOIN `user` u ON u.user_id=a.user_id
            WHERE a.status=0 AND u.status=1 ORDER BY a.created_at DESC,a.application_id
            """;
        await using var c = await OpenAsync(ct);
        return (await c.QueryAsync<AuthorApplicationItem>(Cmd(sql,null,ct))).AsList();
    }

    public async Task DecideAuthorApplicationAsync(Guid adminId, Guid applicationId, ModerationRequest r, CancellationToken ct = default)
    {
        ValidateDecision(r); await using var c=await OpenAsync(ct); await using var tx=await c.BeginTransactionAsync(ct);
        await RequireUserAsync(c,adminId,2,ct,tx);
        var app=await c.QuerySingleOrDefaultAsync<(Guid UserId,byte Status)>(Cmd("SELECT user_id UserId,status Status FROM author_application WHERE application_id=@Id FOR UPDATE",new{Id=applicationId},ct,tx));
        if(app.UserId==Guid.Empty) throw NotFound(); if(app.UserId==adminId) throw Forbidden("Không thể tự duyệt yêu cầu của chính mình."); if(app.Status!=0) throw Conflict("Yêu cầu đã được xử lý.");
        var decision=r.Approve?1:2;
        var changed=await c.ExecuteAsync(Cmd("UPDATE author_application SET status=@Decision,decision_reason=@Reason,reviewed_by=@Admin,reviewed_at=UTC_TIMESTAMP() WHERE application_id=@Id AND status=0",new{Decision=decision,r.Reason,Admin=adminId,Id=applicationId},ct,tx));
        if(changed!=1) throw Conflict("Yêu cầu vừa được xử lý bởi quản trị viên khác.");
        if(r.Approve) await c.ExecuteAsync(Cmd("UPDATE `user` SET role=1 WHERE user_id=@UserId AND status=1 AND role=0",new{app.UserId},ct,tx));
        await AuditAsync(c,tx,5,applicationId,decision,r.Reason,adminId,ct); await tx.CommitAsync(ct);
    }

    public async Task<IReadOnlyList<OwnedNovel>> GetMyNovelsAsync(Guid userId,CancellationToken ct=default)
    { await using var c=await OpenAsync(ct); await RequireUserAsync(c,userId,1,ct); return (await c.QueryAsync<OwnedNovel>(Cmd(OwnedNovelSql+" WHERE n.uploader_id=@UserId GROUP BY n.novel_id,nr.revision_id ORDER BY n.updated_at DESC",new{UserId=userId},ct))).AsList(); }

    public async Task<OwnedNovel?> GetMyNovelAsync(Guid userId,Guid novelId,CancellationToken ct=default)
    { await using var c=await OpenAsync(ct); await RequireUserAsync(c,userId,1,ct); return await c.QuerySingleOrDefaultAsync<OwnedNovel>(Cmd(OwnedNovelSql+" WHERE n.novel_id=@NovelId AND n.uploader_id=@UserId GROUP BY n.novel_id,nr.revision_id",new{NovelId=novelId,UserId=userId},ct)); }

    private const string OwnedNovelSql="""
      SELECT n.novel_id NovelId,n.title Title,n.slug Slug,n.original_author OriginalAuthor,
        n.source_type SourceType,n.source_url SourceUrl,n.description Description,n.cover_url CoverUrl,
        n.completion_status CompletionStatus,n.review_status ReviewStatus,n.visibility Visibility,
        n.reject_reason RejectReason,n.updated_at UpdatedAt,n.deleted_at DeletedAt,
        GROUP_CONCAT(DISTINCT nc.category_id ORDER BY nc.category_id) CategoryIds,
        GROUP_CONCAT(DISTINCT cat.name ORDER BY cat.name SEPARATOR ', ') CategoryNames,
        nr.revision_id RevisionId,nr.review_status RevisionStatus,nr.reject_reason RevisionRejectReason,
        nr.title RevisionTitle
      FROM `novel` n
      LEFT JOIN novel_category nc ON nc.novel_id=n.novel_id
      LEFT JOIN category cat ON cat.category_id=nc.category_id
      LEFT JOIN novel_revision nr ON nr.revision_id=(SELECT x.revision_id FROM novel_revision x WHERE x.novel_id=n.novel_id ORDER BY x.submitted_at DESC LIMIT 1)
      """;

    public async Task<Guid> CreateNovelAsync(Guid userId,NovelWriteRequest r,CancellationToken ct=default)
    {
        ValidateNovel(r); await using var c=await OpenAsync(ct); await using var tx=await c.BeginTransactionAsync(ct); await RequireUserAsync(c,userId,1,ct,tx); await ValidateCategories(c,r.CategoryIds,ct,tx); var id=Guid.NewGuid(); var slug=UniqueSlug(r.Title,id);
        await c.ExecuteAsync(Cmd("""
          INSERT INTO `novel`(novel_id,title,slug,original_author,uploader_id,source_type,source_url,description,cover_url,completion_status,review_status,visibility)
          VALUES(@Id,@Title,@Slug,@OriginalAuthor,@UserId,@SourceType,@SourceUrl,@Description,NULL,@CompletionStatus,0,0)
          """,new{Id=id,Title=r.Title.Trim(),Slug=slug,r.OriginalAuthor,UserId=userId,r.SourceType,r.SourceUrl,r.Description,r.CompletionStatus},ct,tx)); await ReplaceCategories(c,tx,id,r.CategoryIds,ct); await tx.CommitAsync(ct); return id;
    }

    public async Task<Guid?> UpdateNovelAsync(Guid userId,Guid novelId,NovelWriteRequest r,CancellationToken ct=default)
    {
        ValidateNovel(r); await using var c=await OpenAsync(ct); await using var tx=await c.BeginTransactionAsync(ct); await RequireUserAsync(c,userId,1,ct,tx); await ValidateCategories(c,r.CategoryIds,ct,tx);
        var state=await c.QuerySingleOrDefaultAsync<(sbyte ReviewStatus,DateTime? DeletedAt)>(Cmd("SELECT review_status ReviewStatus,deleted_at DeletedAt FROM `novel` WHERE novel_id=@Id AND uploader_id=@UserId FOR UPDATE",new{Id=novelId,UserId=userId},ct,tx));
        if(state==default) throw NotFound(); if(state.DeletedAt is not null) throw Conflict("Tác phẩm đã bị xóa.");
        if(state.ReviewStatus==1)
        {
            var revisionId=Guid.NewGuid();
            try { await c.ExecuteAsync(Cmd("""
              INSERT INTO novel_revision(revision_id,novel_id,submitted_by,title,original_author,source_type,source_url,description,cover_url,completion_status)
              SELECT @RevisionId,n.novel_id,@UserId,@Title,@OriginalAuthor,@SourceType,@SourceUrl,@Description,n.cover_url,@CompletionStatus
              FROM `novel` n WHERE n.novel_id=@NovelId
              """,new{RevisionId=revisionId,NovelId=novelId,UserId=userId,Title=r.Title.Trim(),r.OriginalAuthor,r.SourceType,r.SourceUrl,r.Description,r.CompletionStatus},ct,tx)); }
            catch(MySqlException e) when(e.Number==1062){throw Conflict("Tác phẩm đã có bản sửa đang chờ duyệt.");}
            await tx.CommitAsync(ct); return revisionId;
        }
        await c.ExecuteAsync(Cmd("UPDATE `novel` SET title=@Title,original_author=@OriginalAuthor,source_type=@SourceType,source_url=@SourceUrl,description=@Description,completion_status=@CompletionStatus,review_status=0,reject_reason=NULL WHERE novel_id=@NovelId",new{Title=r.Title.Trim(),r.OriginalAuthor,r.SourceType,r.SourceUrl,r.Description,r.CompletionStatus,NovelId=novelId},ct,tx)); await ReplaceCategories(c,tx,novelId,r.CategoryIds,ct); await tx.CommitAsync(ct); return null;
    }

    public async Task SetNovelVisibilityAsync(Guid userId,Guid novelId,bool visible,CancellationToken ct=default)
    { await using var c=await OpenAsync(ct); await RequireUserAsync(c,userId,1,ct); var n=await c.ExecuteAsync(Cmd("UPDATE `novel` SET visibility=@V WHERE novel_id=@Id AND uploader_id=@UserId AND deleted_at IS NULL AND visibility<>2",new{V=visible?0:1,Id=novelId,UserId=userId},ct)); if(n!=1) throw NotFound(); }
    public async Task SoftDeleteNovelAsync(Guid userId,Guid novelId,CancellationToken ct=default)
    { await using var c=await OpenAsync(ct); await RequireUserAsync(c,userId,1,ct); var n=await c.ExecuteAsync(Cmd("UPDATE `novel` SET deleted_at=UTC_TIMESTAMP(),visibility=1 WHERE novel_id=@Id AND uploader_id=@UserId AND deleted_at IS NULL",new{Id=novelId,UserId=userId},ct)); if(n!=1) throw NotFound(); }

    public async Task<IReadOnlyList<OwnedChapter>> GetMyChaptersAsync(Guid userId,Guid novelId,CancellationToken ct=default)
    { await using var c=await OpenAsync(ct); await RequireOwnedNovelAsync(c,userId,novelId,ct); return (await c.QueryAsync<OwnedChapter>(Cmd("""
      SELECT c.chapter_id ChapterId,c.novel_id NovelId,c.chapter_number ChapterNumber,c.title Title,
        c.content Content,c.review_status ReviewStatus,c.visibility Visibility,c.reject_reason RejectReason,
        c.updated_at UpdatedAt,c.deleted_at DeletedAt,cr.revision_id RevisionId,
        cr.review_status RevisionStatus,cr.reject_reason RevisionRejectReason,
        cr.title RevisionTitle,cr.content RevisionContent
      FROM chapter c LEFT JOIN chapter_revision cr ON cr.revision_id=(SELECT x.revision_id FROM chapter_revision x WHERE x.chapter_id=c.chapter_id ORDER BY x.submitted_at DESC LIMIT 1)
      WHERE c.novel_id=@NovelId ORDER BY c.chapter_number
      """,new{NovelId=novelId},ct))).AsList(); }

    public async Task<Guid> CreateChapterAsync(Guid userId,Guid novelId,ChapterWriteRequest r,CancellationToken ct=default)
    { ValidateChapter(r); await using var c=await OpenAsync(ct); await RequireOwnedNovelAsync(c,userId,novelId,ct); var id=Guid.NewGuid(); try{await c.ExecuteAsync(Cmd("INSERT INTO chapter(chapter_id,novel_id,chapter_number,title,content,review_status,visibility) VALUES(@Id,@NovelId,@ChapterNumber,@Title,@Content,0,0)",new{Id=id,NovelId=novelId,r.ChapterNumber,Title=r.Title.Trim(),r.Content},ct));}catch(MySqlException e)when(e.Number==1062){throw Conflict("Số chương đã tồn tại.");}return id; }

    public async Task<Guid?> UpdateChapterAsync(Guid userId,Guid chapterId,ChapterWriteRequest r,CancellationToken ct=default)
    {
        ValidateChapter(r); await using var c=await OpenAsync(ct); await using var tx=await c.BeginTransactionAsync(ct); await RequireUserAsync(c,userId,1,ct,tx);
        var state=await c.QuerySingleOrDefaultAsync<(Guid NovelId,sbyte ReviewStatus,DateTime? DeletedAt)>(Cmd("SELECT c.novel_id NovelId,c.review_status ReviewStatus,c.deleted_at DeletedAt FROM chapter c INNER JOIN `novel` n ON n.novel_id=c.novel_id WHERE c.chapter_id=@Id AND n.uploader_id=@UserId FOR UPDATE",new{Id=chapterId,UserId=userId},ct,tx)); if(state.NovelId==Guid.Empty)throw NotFound();if(state.DeletedAt is not null)throw Conflict("Chương đã bị xóa.");
        if(state.ReviewStatus==1){var revisionId=Guid.NewGuid();try{await c.ExecuteAsync(Cmd("INSERT INTO chapter_revision(revision_id,chapter_id,submitted_by,title,content) VALUES(@RevisionId,@ChapterId,@UserId,@Title,@Content)",new{RevisionId=revisionId,ChapterId=chapterId,UserId=userId,Title=r.Title.Trim(),r.Content},ct,tx));}catch(MySqlException e)when(e.Number==1062){throw Conflict("Chương đã có bản sửa đang chờ duyệt.");}await tx.CommitAsync(ct);return revisionId;}
        await c.ExecuteAsync(Cmd("UPDATE chapter SET chapter_number=@ChapterNumber,title=@Title,content=@Content,review_status=0,reject_reason=NULL WHERE chapter_id=@Id",new{r.ChapterNumber,Title=r.Title.Trim(),r.Content,Id=chapterId},ct,tx));await tx.CommitAsync(ct);return null;
    }

    public async Task SetChapterVisibilityAsync(Guid userId,Guid chapterId,bool visible,CancellationToken ct=default)
    {await using var c=await OpenAsync(ct);await RequireUserAsync(c,userId,1,ct);var n=await c.ExecuteAsync(Cmd("UPDATE chapter c INNER JOIN `novel` n ON n.novel_id=c.novel_id SET c.visibility=@V WHERE c.chapter_id=@Id AND n.uploader_id=@UserId AND c.deleted_at IS NULL AND c.visibility<>2",new{V=visible?0:1,Id=chapterId,UserId=userId},ct));if(n!=1)throw NotFound();}

    public async Task SoftDeleteChapterAsync(Guid userId,Guid chapterId,CancellationToken ct=default)
    {await using var c=await OpenAsync(ct);await RequireUserAsync(c,userId,1,ct);var n=await c.ExecuteAsync(Cmd("UPDATE chapter c INNER JOIN `novel` n ON n.novel_id=c.novel_id SET c.deleted_at=UTC_TIMESTAMP(),c.visibility=1 WHERE c.chapter_id=@Id AND n.uploader_id=@UserId AND c.deleted_at IS NULL",new{Id=chapterId,UserId=userId},ct));if(n!=1)throw NotFound();}

    public async Task<IReadOnlyList<QueueItem>> GetModerationQueueAsync(CancellationToken ct=default)
    {
        const string sql="""
        SELECT novel_id Id,'novel' TargetType,title Title,uploader_id SubmittedBy,created_at SubmittedAt FROM `novel` WHERE review_status=0 AND deleted_at IS NULL
        UNION ALL SELECT c.chapter_id,'chapter',CONCAT(n.title,' - ',c.title),n.uploader_id,c.created_at FROM chapter c JOIN `novel` n ON n.novel_id=c.novel_id WHERE c.review_status=0 AND c.deleted_at IS NULL AND n.deleted_at IS NULL
        UNION ALL SELECT nr.revision_id,'novelRevision',nr.title,nr.submitted_by,nr.submitted_at FROM novel_revision nr WHERE nr.review_status=0
        UNION ALL SELECT cr.revision_id,'chapterRevision',cr.title,cr.submitted_by,cr.submitted_at FROM chapter_revision cr WHERE cr.review_status=0
        ORDER BY SubmittedAt DESC,Id
        """; await using var c=await OpenAsync(ct);return(await c.QueryAsync<QueueItem>(Cmd(sql,null,ct))).AsList();
    }

    public async Task<ModerationDetail?> GetModerationDetailAsync(string targetType,Guid targetId,CancellationToken ct=default)
    {
        var type=targetType.ToLowerInvariant(); await using var c=await OpenAsync(ct);
        var sql=type switch
        {
            "novel"=>"""SELECT n.novel_id Id,'novel' TargetType,n.uploader_id SubmittedBy,u.full_name SubmitterName,n.created_at SubmittedAt,n.title Title,n.original_author OriginalAuthor,n.source_type SourceType,n.source_url SourceUrl,n.description Description,n.cover_url CoverUrl,n.completion_status CompletionStatus,GROUP_CONCAT(DISTINCT cat.name ORDER BY cat.name SEPARATOR ', ') CategoryNames FROM novel n JOIN user u ON u.user_id=n.uploader_id LEFT JOIN novel_category nc ON nc.novel_id=n.novel_id LEFT JOIN category cat ON cat.category_id=nc.category_id WHERE n.novel_id=@Id AND n.review_status=0 AND n.deleted_at IS NULL GROUP BY n.novel_id""",
            "chapter"=>"""SELECT c.chapter_id Id,'chapter' TargetType,n.uploader_id SubmittedBy,u.full_name SubmitterName,c.created_at SubmittedAt,c.title Title,n.title NovelTitle,c.chapter_number ChapterNumber,c.content Content FROM chapter c JOIN novel n ON n.novel_id=c.novel_id JOIN user u ON u.user_id=n.uploader_id WHERE c.chapter_id=@Id AND c.review_status=0 AND c.deleted_at IS NULL""",
            "novelrevision"=>"""SELECT nr.revision_id Id,'novelRevision' TargetType,nr.submitted_by SubmittedBy,u.full_name SubmitterName,nr.submitted_at SubmittedAt,nr.title Title,nr.original_author OriginalAuthor,nr.source_type SourceType,nr.source_url SourceUrl,nr.description Description,nr.cover_url CoverUrl,nr.completion_status CompletionStatus FROM novel_revision nr JOIN user u ON u.user_id=nr.submitted_by WHERE nr.revision_id=@Id AND nr.review_status=0""",
            "chapterrevision"=>"""SELECT cr.revision_id Id,'chapterRevision' TargetType,cr.submitted_by SubmittedBy,u.full_name SubmitterName,cr.submitted_at SubmittedAt,cr.title Title,n.title NovelTitle,c.chapter_number ChapterNumber,cr.content Content FROM chapter_revision cr JOIN chapter c ON c.chapter_id=cr.chapter_id JOIN novel n ON n.novel_id=c.novel_id JOIN user u ON u.user_id=cr.submitted_by WHERE cr.revision_id=@Id AND cr.review_status=0""",
            _=>throw new PublishingException(400,"Loại kiểm duyệt không hợp lệ.")
        };
        return await c.QuerySingleOrDefaultAsync<ModerationDetail>(Cmd(sql,new{Id=targetId},ct));
    }

    public async Task DecideAsync(Guid adminId,string targetType,Guid targetId,ModerationRequest r,CancellationToken ct=default)
    {
        ValidateDecision(r); await using var c=await OpenAsync(ct);await using var tx=await c.BeginTransactionAsync(ct);await RequireUserAsync(c,adminId,2,ct,tx);var decision=r.Approve?1:2;
        var type=targetType.ToLowerInvariant() switch{"novel"=>1,"chapter"=>2,"novelrevision"=>3,"chapterrevision"=>4,_=>throw new PublishingException(400,"Loại kiểm duyệt không hợp lệ.")};
        if(type==1) await DecideNovel(c,tx,adminId,targetId,r,decision,ct); else if(type==2) await DecideChapter(c,tx,adminId,targetId,r,decision,ct); else if(type==3) await DecideNovelRevision(c,tx,adminId,targetId,r,decision,ct); else await DecideChapterRevision(c,tx,adminId,targetId,r,decision,ct);
        await AuditAsync(c,tx,type,targetId,decision,r.Reason,adminId,ct);await tx.CommitAsync(ct);
    }

    private static async Task DecideNovel(MySqlConnection c,MySqlTransaction tx,Guid admin,Guid id,ModerationRequest r,int d,CancellationToken ct){var owner=await c.ExecuteScalarAsync<Guid?>(Cmd("SELECT uploader_id FROM `novel` WHERE novel_id=@Id AND review_status=0 AND deleted_at IS NULL FOR UPDATE",new{Id=id},ct,tx));if(owner is null)throw Conflict("Tác phẩm không còn chờ duyệt.");if(owner==admin)throw Forbidden("Không thể tự duyệt tác phẩm của mình.");var n=await c.ExecuteAsync(Cmd("UPDATE `novel` SET review_status=@D,reject_reason=@Reason,reviewed_by=@Admin,reviewed_at=UTC_TIMESTAMP(),published_at=IF(@D=1,COALESCE(published_at,UTC_TIMESTAMP()),published_at) WHERE novel_id=@Id AND review_status=0",new{D=d,r.Reason,Admin=admin,Id=id},ct,tx));if(n!=1)throw Conflict("Tác phẩm vừa được xử lý bởi quản trị viên khác.");}
    private static async Task DecideChapter(MySqlConnection c,MySqlTransaction tx,Guid admin,Guid id,ModerationRequest r,int d,CancellationToken ct){var owner=await c.ExecuteScalarAsync<Guid?>(Cmd("SELECT n.uploader_id FROM chapter c JOIN `novel` n ON n.novel_id=c.novel_id WHERE c.chapter_id=@Id AND c.review_status=0 AND c.deleted_at IS NULL FOR UPDATE",new{Id=id},ct,tx));if(owner is null)throw Conflict("Chương không còn chờ duyệt.");if(owner==admin)throw Forbidden("Không thể tự duyệt chương của mình.");var n=await c.ExecuteAsync(Cmd("UPDATE chapter SET review_status=@D,reject_reason=@Reason,reviewed_by=@Admin,reviewed_at=UTC_TIMESTAMP(),published_at=IF(@D=1,COALESCE(published_at,UTC_TIMESTAMP()),published_at) WHERE chapter_id=@Id AND review_status=0",new{D=d,r.Reason,Admin=admin,Id=id},ct,tx));if(n!=1)throw Conflict("Chương vừa được xử lý bởi quản trị viên khác.");}
    private static async Task DecideNovelRevision(MySqlConnection c,MySqlTransaction tx,Guid admin,Guid id,ModerationRequest r,int d,CancellationToken ct){var x=await c.QuerySingleOrDefaultAsync<dynamic>(Cmd("SELECT * FROM novel_revision WHERE revision_id=@Id AND review_status=0 FOR UPDATE",new{Id=id},ct,tx));if(x is null)throw Conflict("Bản sửa không còn chờ duyệt.");if((Guid)x.submitted_by==admin)throw Forbidden("Không thể tự duyệt bản sửa của mình.");if(d==1){var applied=await c.ExecuteAsync(Cmd("UPDATE `novel` SET title=@title,original_author=@original_author,source_type=@source_type,source_url=@source_url,description=@description,cover_url=@cover_url,completion_status=@completion_status WHERE novel_id=@novel_id AND deleted_at IS NULL",(object)x,ct,tx));if(applied!=1)throw Conflict("Tác phẩm gốc đã bị xóa hoặc không còn hợp lệ.");}var n=await c.ExecuteAsync(Cmd("UPDATE novel_revision SET review_status=@D,reject_reason=@Reason,reviewed_by=@Admin,reviewed_at=UTC_TIMESTAMP() WHERE revision_id=@Id AND review_status=0",new{D=d,r.Reason,Admin=admin,Id=id},ct,tx));if(n!=1)throw Conflict("Bản sửa vừa được xử lý bởi quản trị viên khác.");}
    private static async Task DecideChapterRevision(MySqlConnection c,MySqlTransaction tx,Guid admin,Guid id,ModerationRequest r,int d,CancellationToken ct){var x=await c.QuerySingleOrDefaultAsync<dynamic>(Cmd("SELECT * FROM chapter_revision WHERE revision_id=@Id AND review_status=0 FOR UPDATE",new{Id=id},ct,tx));if(x is null)throw Conflict("Bản sửa không còn chờ duyệt.");if((Guid)x.submitted_by==admin)throw Forbidden("Không thể tự duyệt bản sửa của mình.");if(d==1){var applied=await c.ExecuteAsync(Cmd("UPDATE chapter SET title=@title,content=@content WHERE chapter_id=@chapter_id AND deleted_at IS NULL",(object)x,ct,tx));if(applied!=1)throw Conflict("Chương gốc đã bị xóa hoặc không còn hợp lệ.");}var n=await c.ExecuteAsync(Cmd("UPDATE chapter_revision SET review_status=@D,reject_reason=@Reason,reviewed_by=@Admin,reviewed_at=UTC_TIMESTAMP() WHERE revision_id=@Id AND review_status=0",new{D=d,r.Reason,Admin=admin,Id=id},ct,tx));if(n!=1)throw Conflict("Bản sửa vừa được xử lý bởi quản trị viên khác.");}

    private async Task<MySqlConnection> OpenAsync(CancellationToken ct){var c=new MySqlConnection(_cs);await c.OpenAsync(ct);return c;}
    private static CommandDefinition Cmd(string sql,object? p,CancellationToken ct,MySqlTransaction? tx=null)=>new(sql,p,tx,cancellationToken:ct);
    private static async Task RequireUserAsync(MySqlConnection c,Guid id,byte role,CancellationToken ct,MySqlTransaction? tx=null){var u=await c.QuerySingleOrDefaultAsync<(sbyte Role,sbyte Status)>(Cmd("SELECT role Role,status Status FROM `user` WHERE user_id=@Id",new{Id=id},ct,tx));if(u==default)throw new PublishingException(401,"Tài khoản không tồn tại.");if(u.Status!=1)throw Forbidden("Tài khoản đang bị khóa.");if(u.Role!=role)throw Forbidden("Vai trò tài khoản không phù hợp.");}
    private static async Task RequireOwnedNovelAsync(MySqlConnection c,Guid user,Guid novel,CancellationToken ct,MySqlTransaction? tx=null){await RequireUserAsync(c,user,1,ct,tx);var ok=await c.ExecuteScalarAsync<bool>(Cmd("SELECT EXISTS(SELECT 1 FROM `novel` WHERE novel_id=@Novel AND uploader_id=@User AND deleted_at IS NULL)",new{Novel=novel,User=user},ct,tx));if(!ok)throw NotFound();}
    private static async Task AuditAsync(MySqlConnection c,MySqlTransaction tx,int type,Guid id,int decision,string? reason,Guid admin,CancellationToken ct)=>await c.ExecuteAsync(Cmd("INSERT INTO moderation_decision(target_type,target_id,decision,reason,reviewed_by) VALUES(@Type,@Id,@Decision,@Reason,@Admin)",new{Type=type,Id=id,Decision=decision,Reason=reason,Admin=admin},ct,tx));
    private static async Task ValidateCategories(MySqlConnection c,IReadOnlyList<Guid>? ids,CancellationToken ct,MySqlTransaction tx){if(ids is null||ids.Count==0)return;var count=await c.ExecuteScalarAsync<int>(Cmd("SELECT COUNT(*) FROM category WHERE category_id IN @Ids AND is_active=1",new{Ids=ids.Distinct().ToArray()},ct,tx));if(count!=ids.Distinct().Count())throw new PublishingException(400,"Thể loại không hợp lệ hoặc đã bị ẩn.");}
    private static async Task ReplaceCategories(MySqlConnection c,MySqlTransaction tx,Guid novelId,IReadOnlyList<Guid>? ids,CancellationToken ct){await c.ExecuteAsync(Cmd("DELETE FROM novel_category WHERE novel_id=@NovelId",new{NovelId=novelId},ct,tx));foreach(var id in ids?.Distinct()??Enumerable.Empty<Guid>())await c.ExecuteAsync(Cmd("INSERT INTO novel_category(novel_id,category_id) VALUES(@NovelId,@CategoryId)",new{NovelId=novelId,CategoryId=id},ct,tx));}
    private static void ValidateDecision(ModerationRequest r){if(!r.Approve&&string.IsNullOrWhiteSpace(r.Reason))throw new PublishingException(400,"Từ chối phải có lý do.");}
    private static void ValidateNovel(NovelWriteRequest r){if(string.IsNullOrWhiteSpace(r.Title)||r.Title.Length>255)throw new PublishingException(400,"Tên truyện không hợp lệ.");if(r.SourceType>1||r.CompletionStatus>2)throw new PublishingException(400,"Trạng thái không hợp lệ.");}
    private static void ValidateChapter(ChapterWriteRequest r){if(r.ChapterNumber==0||string.IsNullOrWhiteSpace(r.Title)||string.IsNullOrWhiteSpace(r.Content))throw new PublishingException(400,"Dữ liệu chương không hợp lệ.");}
    private static PublishingException Conflict(string m)=>new(409,m);private static PublishingException Forbidden(string m)=>new(403,m);private static PublishingException NotFound()=>new(404,"Không tìm thấy dữ liệu hoặc bạn không có quyền.");
    private static string UniqueSlug(string title,Guid id){var slug=SlugRegex().Replace(title.Trim().ToLowerInvariant().Normalize(System.Text.NormalizationForm.FormD),"-").Trim('-');if(string.IsNullOrEmpty(slug))slug="novel";return $"{slug}-{id.ToString("N")[..8]}";}
    [GeneratedRegex("[^a-z0-9]+",RegexOptions.Compiled)] private static partial Regex SlugRegex();
}
