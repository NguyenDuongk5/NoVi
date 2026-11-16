# NoVi Flutter

Ứng dụng độc giả Flutter kết nối trực tiếp với backend NoVi. Bản này có đăng ký/đăng nhập, hồ sơ, khám phá và tìm kiếm truyện, lọc thể loại, chi tiết/chương, tủ sách, lịch sử và trình đọc có lưu tiến độ.

## Chạy ứng dụng

Backend phải trỏ vào database `novi_test`. URL API được truyền lúc build/run, không ghi cứng theo môi trường:

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5148
```

Các URL thường dùng:

- Windows/macOS/Linux hoặc Chrome cùng máy: `http://localhost:5148`
- Android Emulator chuẩn: `http://10.0.2.2:5148`
- Thiết bị Android/iOS thật: `http://<IP-LAN-của-máy-chạy-backend>:5148`; backend phải lắng nghe trên interface LAN và firewall phải cho phép cổng 5148.
- iOS Simulator: thường dùng `http://localhost:5148`. Với HTTP nội bộ, cấu hình ATS phù hợp cho môi trường phát triển; production nên dùng HTTPS.

Ví dụ Android Emulator:

```powershell
flutter run -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:5148
```

Giá trị mặc định hiện là `http://10.0.2.2:5148`, phù hợp Android Emulator. Android đã có quyền Internet và cho phép cleartext để kết nối backend HTTP khi phát triển; bản production nên chuyển sang HTTPS và tắt cleartext.

## Xác thực và dữ liệu riêng

- App sử dụng đúng access token backend trả về; không tự tạo refresh-token flow.
- Token, hạn token và hồ sơ tối thiểu được lưu bằng `flutter_secure_storage`.
- Khi token hết hạn hoặc API trả 401, app đăng xuất, xóa token/hồ sơ đã lưu và các trang riêng được dựng lại theo `userId` mới.
- Tùy chọn trình đọc (cỡ chữ, nền đọc) là tùy chọn thiết bị, không phải dữ liệu riêng theo tài khoản.
- Web storage phụ thuộc cơ chế bảo mật của trình duyệt; không tương đương kho khóa phần cứng của Android/iOS/desktop.

## Luồng đọc

- Khách có thể gọi API nội dung công khai.
- Người đăng nhập tạo một read session khi thực sự mở/chuyển chương, sau đó gọi endpoint view riêng đúng một lần cho lần mở đó.
- Cuộn trang ghi progress sau debounce 700 ms, kèm `sessionId` và `sequence` tăng dần.
- Mỗi lần chuyển chương tăng generation để response/callback cũ không ghi nhầm chương mới.
- HTTP 409 chỉ hiển thị thông báo rằng tiến độ mới hơn được giữ; app không retry vô hạn.
- “Tiếp tục đọc” lấy chương/vị trí từ backend và khôi phục cuộn sau frame layout đầu tiên.

## API backend đang dùng

- `POST /api/auth/register`, `POST /api/auth/login`
- `GET /api/users/me`, `PATCH /api/users/me`
- `GET /api/novels`, `GET /api/categories`
- `GET /api/novels/{id}`, `GET /api/novels/{id}/chapters`, `GET /api/novels/chapters/{chapterId}`
- `GET|PUT|DELETE /api/me/library...`
- `GET /api/me/history`
- `POST .../sessions`, `PUT .../progress`, `POST .../views`, `GET .../continue`

UI không có endpoint giả và không chứa Firebase credential. Ảnh thiếu/lỗi dùng placeholder cục bộ.

## Bố cục giao diện độc giả

- Trang chủ dùng dữ liệu thật từ `GET /api/novels` và `GET /api/categories`. Menu đầu trang có hai nội dung thực: **Khám phá** (truyện mới và danh sách khám phá) và **Thể loại** (lọc theo category).
- Điều hướng độc giả gồm **Khám phá – Tủ sách – Tôi**. Tủ sách chứa hai mục con **Đã lưu** và **Lịch sử**, đúng mô tả thư viện cá nhân trong báo cáo.
- Báo cáo không đặc tả bảng xếp hạng, đề xuất cá nhân, Truyện Chat hoặc DramaHub; giao diện không tạo nút/tab giả cho các chức năng này.
- Thanh “Đọc tiếp” chỉ xuất hiện khi tài khoản có tiến độ còn khả dụng. Việc hiển thị thanh không tạo read session, history hoặc view.
- Nội dung giới hạn tối đa 760 logical pixel trên màn hình lớn; điện thoại dùng lề ngang 16 logical pixel.
- Màu chính lấy từ `ThemeData.colorScheme` với seed hồng `#E86B9A`. Màn hình đọc vẫn giữ nền và cỡ chữ người dùng đã chọn.
- Giao diện hỗ trợ **Sáng / Tối / Theo hệ thống**. Có thể đổi nhanh bằng biểu tượng trên Trang chủ hoặc vào **Hồ sơ → Giao diện**; lựa chọn được lưu cục bộ trước khi dựng ứng dụng.
- Seed bộ bìa minh họa thật (chỉ `novi_test`): `powershell -File tooling/seed_demo_library.ps1`. Danh sách đối chiếu ảnh/tên và các mục chưa đủ thông tin thể loại nằm tại `docs/DEMO_LIBRARY.md`.
- Không hiển thị số liệu giả hoặc chức năng ngoài API/báo cáo hiện có.
- Bảng xếp hạng lượt đọc là chức năng bổ sung theo yêu cầu mới. Trang chủ tải top 9 tháng; màn hình đầy đủ hỗ trợ tuần/tháng/toàn bộ, hoàn thành và thể loại thật qua `GET /api/novels/rankings`.

## Kết quả kiểm tra ngày 30/10/2026

- `flutter test`: PASS, 7/7 test, gồm DTO/response cũ của BXH.
- Windows ranking E2E với backend Release và `novi_test`: PASS. Xem `RANKING_FLUTTER_TEST_MATRIX.md`.
- `flutter build windows --debug --dart-define=API_BASE_URL=http://localhost:5148`: PASS; artifact tại `build/windows/x64/runner/Debug/`.
- `flutter analyze`: không có error; còn 57 warning/info trong source prototype cũ và dự án Flutter lồng `FE/flutter_application_1`.
- `flutter analyze lib/ui lib/core lib/main.dart integration_test test`: PASS, `No issues found` cho toàn bộ mã NoVi mới và test mới.
- Windows integration E2E với backend thật + `novi_test`: PASS. Xem `FLUTTER_E2E_TEST_MATRIX.md`.
- Thiết bị phát hiện: Windows, Chrome, Edge. Không có Android emulator/điện thoại đang chạy; Android licenses chưa được chấp nhận.
- Windows UI E2E đã chạy thật bằng `integration_test`; Android/iOS vẫn chưa chạy trên emulator/thiết bị.

Để hoàn tất kiểm thử thiết bị Android: chạy `flutter doctor --android-licenses`, khởi động emulator, bảo đảm backend `novi_test` ở cổng 5148, rồi chạy lệnh Android ở trên. Không dùng database `novi`.
