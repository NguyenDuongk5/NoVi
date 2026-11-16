# Flutter NoVi Windows E2E test matrix

Ngày chạy: 30/10/2026. Backend được khởi động tại `http://localhost:5148` với connection string sinh trong runtime và `Database=novi_test`. Script dừng ngay nếu `SELECT DATABASE()` không trả `novi_test`. Fixture dùng email, truyện, hai chương và thể loại có hậu tố UUID riêng; không thao tác database `novi`.

| Nhóm | Kết quả | Bằng chứng thực tế |
|---|---|---|
| Khởi động backend an toàn | PASS | `tooling/run_flutter_windows_e2e.ps1` xác minh `SELECT DATABASE() = novi_test`, API public sẵn sàng trước khi chạy Flutter. |
| Windows runner | PASS | `flutter test integration_test/reader_flow_test.dart -d windows`; ứng dụng Windows được build và test runner báo `All tests passed`. |
| Khách: danh sách/tìm kiếm/lọc | PASS | UI tìm đúng fixture theo tiêu đề, chọn thể loại fixture và vẫn thấy đúng truyện. |
| Khách: chi tiết/đọc/chuyển chương | PASS | UI mở chi tiết, chương 1, kiểm tra nội dung dài và chuyển sang chương 2. |
| Đăng ký và sửa hồ sơ | PASS | Đăng ký qua form, PATCH hồ sơ qua UI và quan sát tên hiển thị mới. |
| Đăng xuất và đăng nhập | PASS | Đăng xuất, đăng nhập lại tài khoản đã tạo qua form và quan sát đúng email. |
| Secure token sau dựng lại app | PASS | Dựng một `Session` và widget tree mới; secure storage khôi phục đúng tài khoản. |
| HTTP 401 | PASS | Thay access token bằng token không hợp lệ, mở Tủ sách, backend trả 401; UI về login gate và `access_token` trong secure storage là null. |
| Tủ sách lưu và tải lại | PASS | Lưu truyện trong chi tiết; chuyển tab Tủ sách và thấy fixture. Lỗi state cũ không refresh đã được phát hiện và sửa. |
| Bỏ lưu lặp | NOT RUN | Backend đã có integration riêng; thao tác UI bỏ lưu lặp chưa được tự động hóa trong lượt này. |
| Phân trang Tủ sách >20 | NOT RUN | Fixture E2E chỉ tạo một truyện, không dùng API test thay cho bằng chứng UI. |
| Trình đọc: cuộn/font/nền/chuyển chương | PASS | Runner cuộn nội dung dài, chọn Chữ lớn, Nền vàng rồi chuyển chương. |
| Flush progress khi chuyển/rời màn hình | PASS | Đã sửa `flushProgress()` trước chuyển chương và PopScope trước pop; E2E chuyển chương/đóng reader, sau đó DB có progress. |
| Không ghi progress=0 khi restore | PASS | Restore được suppress qua hai frame; request observer của E2E xác nhận không có PUT progress phát sinh từ lúc bấm Continue đến khi nội dung đã restore/layout. |
| Callback chương cũ | PASS | Generation guard giữ request theo chương; E2E chuyển chương và continue trả chương 2, DB không bị chapter cũ giành lại continue. |
| Đổi cỡ chữ giữ vị trí | PASS | Đã giữ phần trăm logic, suppress callback khi re-layout; E2E đổi font rồi lưu/chuyển chương và DB progress vẫn >0. |
| Lịch sử | PASS | Sau mở chương, tab Lịch sử hiển thị fixture. |
| Continue và khởi động lại | PASS | Continue mở đúng `Chapter two`; sau đó app được dựng lại và vẫn khôi phục tài khoản. |
| Cách ly tài khoản | PASS | Tài khoản thứ hai thấy Tủ sách trống và Lịch sử trống. |
| Session/history/progress/view | PASS | Integration test truy vấn `novi_test`; cả bốn bảng có số bản ghi >0 cho tài khoản fixture. |
| Tài khoản khóa | PASS một phần | Trạng thái tài khoản fixture thứ hai được chuyển inactive trong `novi_test`; UI không crash. Kiểm tra đầy đủ mọi màn hình sau 403 chưa chạy. |
| Nội dung ẩn sau khi đã tải | PASS | Fixture chapter được ẩn trong `novi_test`; mở lại từ danh sách cũ nhận màn hình lỗi/Thử lại, không crash; fixture được hiện lại sau assertion. |
| Nội dung xóa mềm sau khi tải | NOT RUN | Chưa tự động hóa riêng trên Windows UI. |
| Mất kết nối và Thử lại | NOT RUN | Runner chưa dừng/khởi động backend giữa một test UI; không suy diễn từ ErrorRetry widget. |
| HTTP 409 progress | NOT RUN | Backend đã kiểm thử hợp đồng nhưng Windows UI chưa được cưỡng bức nhận 409 trong runner. |
| Token hết hạn theo thời gian | NOT RUN | Đã chạy HTTP 401 token không hợp lệ; chưa chờ token thật hết hạn. |

## Lệnh tái chạy

```powershell
.\tooling\run_flutter_windows_e2e.ps1
flutter test
flutter analyze
flutter build windows --debug --dart-define=API_BASE_URL=http://localhost:5148
```

Script sinh DB password, JWT key và fixture password trong bộ nhớ, không in hoặc commit chúng. Backend và fixture chỉ dùng `novi_test`.

## Kiểm tra tĩnh và build sau cùng

- `flutter test --no-pub -r expanded`: PASS 2/2.
- Analyzer giới hạn mã đang dùng (`lib/ui`, `lib/core`, `lib/main.dart`, `integration_test`, `test`): PASS, không có issue.
- `flutter analyze` toàn repository: không có error; còn 57 warning/info thuộc prototype cũ và dự án lồng `FE/flutter_application_1`.
- `flutter build windows --debug --dart-define=API_BASE_URL=http://localhost:5148`: PASS.
