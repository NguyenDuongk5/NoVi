using SkiaSharp;
namespace ReadBookApi.Media;
public sealed record ValidatedImage(MemoryStream Stream,string ContentType,string Extension,int Width,int Height):IDisposable{public void Dispose()=>Stream.Dispose();}
public static class ImageFileValidator
{
    public static async Task<ValidatedImage> ValidateAsync(IFormFile file,long maxBytes,CancellationToken ct)
    {
        if(file.Length<=0||file.Length>maxBytes)throw new MediaException(400,$"File phải có dung lượng từ 1 đến {maxBytes} byte.");
        var ms=new MemoryStream((int)file.Length);await file.CopyToAsync(ms,ct);ms.Position=0;
        try
        {
            using var decodeStream=new SKMemoryStream(ms.ToArray());
            using var codec=SKCodec.Create(decodeStream)??throw new MediaException(400,"Nội dung file không phải ảnh hợp lệ.");
            var (mime,ext)=codec.EncodedFormat switch{SKEncodedImageFormat.Jpeg=>("image/jpeg","jpg"),SKEncodedImageFormat.Png=>("image/png","png"),SKEncodedImageFormat.Webp=>("image/webp","webp"),_=>throw new MediaException(400,"Chỉ hỗ trợ JPEG, PNG hoặc WebP.")};
            var info=codec.Info;if(info.Width<=0||info.Height<=0||info.Width>10000||info.Height>10000||(long)info.Width*info.Height>40_000_000)throw new MediaException(400,"Kích thước ảnh sau giải mã vượt giới hạn.");
            using var bitmap=new SKBitmap(info);var result=codec.GetPixels(bitmap.Info,bitmap.GetPixels());if(result!=SKCodecResult.Success)throw new MediaException(400,"Dữ liệu ảnh bị hỏng hoặc không thể giải mã.");
            ms.Position=0;return new(ms,mime,ext,info.Width,info.Height);
        }
        catch(MediaException){ms.Dispose();throw;}catch(Exception){ms.Dispose();throw new MediaException(400,"Dữ liệu ảnh bị hỏng hoặc không thể giải mã.");}
    }
}
public sealed class MediaException(int status,string message):Exception(message){public int StatusCode{get;}=status;}
