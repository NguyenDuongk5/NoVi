using ReadBookRepo.Media;

namespace ReadBookApi.Media;

public sealed record OrphanMediaItem(string ObjectName,DateTimeOffset? UpdatedAt);
public sealed record OrphanMediaResult(bool DryRun,int Scanned,int Referenced,IReadOnlyList<OrphanMediaItem> Candidates,int Deleted);

public sealed class OrphanMediaService(IMediaStorage storage,IMediaRepository repository)
{
    public async Task<OrphanMediaResult> RunAsync(int minAgeHours,bool delete,CancellationToken ct)
    {
        if(!string.Equals(storage.EnvironmentPrefix.Trim('/'),"test",StringComparison.Ordinal))
            throw new MediaException(403,"Công cụ dọn object chỉ được phép chạy với prefix test.");
        if(minAgeHours<1)throw new MediaException(400,"minAgeHours phải từ 1 trở lên.");
        if(delete&&!storage.AllowOrphanDelete)throw new MediaException(403,"Xóa object chưa được bật; hãy chạy dry-run.");
        var references=await repository.GetReferencedMediaUrlsAsync(ct);
        var cutoff=DateTimeOffset.UtcNow.AddHours(-minAgeHours);
        var candidates=new List<OrphanMediaItem>();
        var scanned=0;
        await foreach(var item in storage.ListAsync($"{storage.EnvironmentPrefix.Trim('/')}/",ct))
        {
            scanned++;
            if(item.UpdatedAt is null||item.UpdatedAt>cutoff||references.Contains(item.Url))continue;
            candidates.Add(new(item.ObjectName,item.UpdatedAt));
        }
        var deleted=0;
        if(delete)foreach(var item in candidates){await storage.DeleteAsync(item.ObjectName,ct);deleted++;}
        return new(!delete,scanned,references.Count,candidates,deleted);
    }
}
