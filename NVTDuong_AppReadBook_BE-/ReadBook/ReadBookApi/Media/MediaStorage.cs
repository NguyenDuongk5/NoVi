using Google.Cloud.Storage.V1;
using Microsoft.Extensions.Options;
namespace ReadBookApi.Media;
public sealed record StoredMediaObject(string ObjectName,string Url,DateTimeOffset? UpdatedAt);
public interface IMediaStorage{string EnvironmentPrefix{get;}bool AllowOrphanDelete{get;}Task<(string ObjectName,string Url)> UploadAsync(Stream data,string contentType,string area,string extension,CancellationToken ct);Task DeleteAsync(string objectName,CancellationToken ct);IAsyncEnumerable<StoredMediaObject> ListAsync(string prefix,CancellationToken ct);}
public sealed class FirebaseMediaStorage:IMediaStorage
{
    private readonly FirebaseOptions _o;
    public FirebaseMediaStorage(IOptions<FirebaseOptions> options)=>_o=options.Value;
    public string EnvironmentPrefix=>_o.EnvironmentPrefix;
    public bool AllowOrphanDelete=>_o.AllowOrphanDelete;
    public async Task<(string ObjectName,string Url)> UploadAsync(Stream data,string contentType,string area,string extension,CancellationToken ct){Validate();var client=StorageClient.Create();var name=$"{_o.EnvironmentPrefix.Trim('/')}/{area}/{Guid.NewGuid():N}.{extension}";await client.UploadObjectAsync(_o.Bucket,name,contentType,data,cancellationToken:ct);return(name,BuildUrl(name));}
    public async Task DeleteAsync(string objectName,CancellationToken ct){Validate();try{await StorageClient.Create().DeleteObjectAsync(_o.Bucket,objectName,cancellationToken:ct);}catch(Google.GoogleApiException e)when(e.HttpStatusCode==System.Net.HttpStatusCode.NotFound){}}
    public async IAsyncEnumerable<StoredMediaObject> ListAsync(string prefix,[System.Runtime.CompilerServices.EnumeratorCancellation]CancellationToken ct){Validate();var objects=StorageClient.Create().ListObjectsAsync(_o.Bucket,prefix);await foreach(var item in objects.WithCancellation(ct))yield return new(item.Name,BuildUrl(item.Name),item.UpdatedDateTimeOffset);}
    private string BuildUrl(string name){var root=string.IsNullOrWhiteSpace(_o.PublicBaseUrl)?$"https://storage.googleapis.com/{_o.Bucket}":_o.PublicBaseUrl.TrimEnd('/');return $"{root}/{string.Join('/',name.Split('/').Select(Uri.EscapeDataString))}";}
    private void Validate(){if(string.IsNullOrWhiteSpace(_o.Bucket))throw new MediaException(503,"Firebase Storage chưa được cấu hình.");if(string.IsNullOrWhiteSpace(_o.EnvironmentPrefix))throw new MediaException(503,"Firebase EnvironmentPrefix chưa được cấu hình.");}
}

public sealed class LocalMediaStorage : IMediaStorage
{
    private readonly MediaOptions _options;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly string _uploadsRoot;
    public string EnvironmentPrefix => _options.EnvironmentPrefix;
    public bool AllowOrphanDelete => _options.AllowOrphanDelete;

    public LocalMediaStorage(
        IOptions<MediaOptions> options,
        IWebHostEnvironment environment,
        IHttpContextAccessor httpContextAccessor)
    {
        _options = options.Value;
        _httpContextAccessor = httpContextAccessor;
        var webRoot = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var relativeRoot = _options.LocalRoot.Trim().Trim('/', '\\');
        if (string.IsNullOrWhiteSpace(relativeRoot) || Path.IsPathRooted(relativeRoot))
            throw new InvalidOperationException("Media:LocalRoot must be a relative directory below wwwroot.");
        _uploadsRoot = Path.GetFullPath(Path.Combine(webRoot, relativeRoot));
        if (!_uploadsRoot.StartsWith(webRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Media:LocalRoot must stay below wwwroot.");
    }

    public async Task<(string ObjectName, string Url)> UploadAsync(
        Stream data, string contentType, string area, string extension, CancellationToken ct)
    {
        var objectName = BuildObjectName(area, extension);
        var path = ResolvePath(objectName);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        try
        {
            await using var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true);
            await data.CopyToAsync(output, ct);
        }
        catch
        {
            try { File.Delete(path); } catch { }
            throw;
        }
        return (objectName, BuildUrl(objectName));
    }

    public Task DeleteAsync(string objectName, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var path = ResolvePath(objectName);
        if (File.Exists(path)) File.Delete(path);
        return Task.CompletedTask;
    }

    public async IAsyncEnumerable<StoredMediaObject> ListAsync(
        string prefix,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct)
    {
        var prefixPath = ResolvePath(prefix.TrimEnd('/') + "/placeholder");
        var directory = Path.GetDirectoryName(prefixPath)!;
        if (!Directory.Exists(directory)) yield break;
        foreach (var path in Directory.EnumerateFiles(directory, "*", SearchOption.AllDirectories))
        {
            ct.ThrowIfCancellationRequested();
            var objectName = Path.GetRelativePath(_uploadsRoot, path).Replace('\\', '/');
            yield return new StoredMediaObject(objectName, BuildUrl(objectName), File.GetLastWriteTimeUtc(path));
            await Task.Yield();
        }
    }

    private string BuildObjectName(string area, string extension)
    {
        var safeArea = area is "avatars" or "covers" ? area : throw new MediaException(400, "Khu vực lưu ảnh không hợp lệ.");
        var safeExtension = extension is "jpg" or "png" or "webp" ? extension : throw new MediaException(400, "Phần mở rộng ảnh không hợp lệ.");
        var prefix = _options.EnvironmentPrefix.Trim('/');
        if (string.IsNullOrWhiteSpace(prefix) || prefix.Contains("..", StringComparison.Ordinal))
            throw new MediaException(503, "Media EnvironmentPrefix chưa được cấu hình hợp lệ.");
        return $"{prefix}/{safeArea}/{Guid.NewGuid():N}.{safeExtension}";
    }

    private string ResolvePath(string objectName)
    {
        var relative = objectName.Replace('/', Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar);
        var path = Path.GetFullPath(Path.Combine(_uploadsRoot, relative));
        if (!path.StartsWith(_uploadsRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new MediaException(400, "Đường dẫn media không hợp lệ.");
        return path;
    }

    private string BuildUrl(string objectName)
    {
        var baseUrl = _options.PublicBaseUrl?.TrimEnd('/');
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            var request = _httpContextAccessor.HttpContext?.Request
                ?? throw new MediaException(503, "Không thể xác định URL public cho media local.");
            baseUrl = $"{request.Scheme}://{request.Host}";
        }
        var root = _options.LocalRoot.Trim().Trim('/', '\\');
        var encoded = string.Join('/', objectName.Split('/').Select(Uri.EscapeDataString));
        return $"{baseUrl}/{root}/{encoded}";
    }
}
