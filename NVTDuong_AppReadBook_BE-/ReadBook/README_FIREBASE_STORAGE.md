# Firebase Storage backend

Firebase remains supported, but it is optional. For local disk storage without Firebase billing, see `README_MEDIA_STORAGE.md` and set `Media__Provider=Local`. If unset, the provider remains Firebase for backward compatibility.

## Cấu hình máy kiểm thử

Credentials chỉ nằm ở backend. Tạo/chọn bucket test, tạo service account server-only có quyền create/get/list/delete object trên bucket, rồi lưu JSON ngoài repository. Không gửi JSON/key qua chat và không đặt key trong `appsettings.json` hay Flutter.

Trong đúng PowerShell dùng để chạy API:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS='C:\secure\novi-firebase.json'
$env:Firebase__Bucket='project-id.appspot.com'
$env:Firebase__EnvironmentPrefix='test'
$env:Firebase__PublicBaseUrl='https://storage.googleapis.com/project-id.appspot.com'
$env:Firebase__AllowOrphanDelete='false'
```

Chỉ dùng prefix `test` cùng database `novi_test`. Backend hiện lưu URL GCS ổn định, không chứa token. Chỉ cấp quyền đọc công khai cho `test/avatars/` và `test/covers/`, hoặc đặt riêng hai prefix này sau CDN công khai; không mở public toàn bucket. Nếu policy tổ chức không cho public-read theo prefix, cần thiết kế private CDN/signed-cookie trước production, không lưu signed URL hết hạn vào database.

## API

- `POST /api/media/avatar`: JWT, tài khoản hoạt động, multipart field `file`, tối đa 2 MiB.
- `POST /api/media/novels/{novelId}/cover`: JWT tác giả, đúng chủ sở hữu, tối đa 5 MiB.
- `POST /api/admin/media/orphans?minAgeHours=24&delete=false`: admin; dry-run mặc định.

Chỉ JPEG, PNG, WebP giải mã thành công được nhận. Giới hạn giải mã là 10.000 x 10.000 và 40 triệu pixel. Tên object ngẫu nhiên dưới `{prefix}/avatars` hoặc `{prefix}/covers`.

Avatar cập nhật `user.avatar_url`. Bìa của truyện đã duyệt tạo `novel_revision`; bìa công khai giữ nguyên đến khi revision được duyệt. Nếu đã có revision chờ, API trả 409 và dọn object vừa tải. Khi ghi database lỗi, object vừa tải cũng được dọn. Object cũ không bị xóa vì có thể vẫn được bản công khai/revision tham chiếu.

Công cụ orphan chỉ chạy khi prefix chính xác là `test`, có thời gian chờ tối thiểu một giờ, và đối chiếu `user.avatar_url`, `novel.cover_url`, `novel_revision.cover_url`. Xóa thật còn yêu cầu `Firebase__AllowOrphanDelete=true`. Không bật/xóa thật trong đợt xác minh này.

## Decoder và giấy phép

API dùng `SkiaSharp` 3.119.0 (MIT) để giải mã pixel và kiểm tra định dạng thật. ImageSharp đã bị gỡ vì phiên bản được cài dùng giấy phép split/commercial của Six Labors và chưa xác định dự án đủ điều kiện community. Các kiểm tra dung lượng, file hỏng, định dạng, kích thước và số pixel được giữ nguyên.

## Trạng thái

Debug và Release build được mà không cần Firebase. Ngày 2026-10-29, credentials/bucket/prefix/public base URL đều chưa được thiết lập nên upload thật vẫn BLOCKED. Chỉ chuyển sang PASS sau khi quan sát object được tạo, URL đọc được, database/revision đúng, rollback dọn file và orphan dry-run trên `test` + `novi_test`.
