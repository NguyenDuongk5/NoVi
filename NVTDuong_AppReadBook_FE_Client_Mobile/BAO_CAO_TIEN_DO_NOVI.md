# BÁO CÁO TIẾN ĐỘ VÀ CHECKLIST KIỂM THỬ NOVI

> Ngày rà soát: **16/11/2026**  
> Phạm vi: Flutter tại repository hiện tại, .NET 8 Web API `ReadBookApi`, MySQL schema/migration, tài liệu và test có thể truy cập.  
> Quy ước: **PASS** chỉ dùng cho ca có bằng chứng đã chạy; “PASS (trước đây)” là kết quả lưu trong ma trận cũ, không phải lần rà soát này.

## 1. Tổng quan tiến độ

### 1.1. Mốc source và môi trường

| Mục | Giá trị kiểm tra |
|---|---|
| Ngày kiểm tra | 16/11/2026, múi giờ Asia/Saigon |
| Flutter repository | `NVTDuong_AppReadBook_FE_Client_Mobile` |
| Git | branch `main`, commit `7e1042c`; working tree đang có nhiều thay đổi/chưa track từ các đợt triển khai trước |
| Backend | `../NVTDuong_AppReadBook_BE-/ReadBook`, .NET SDK `8.0.403`, solution `ReadBookApi.sln` |
| Flutter | Flutter `3.35.3`, Dart `3.9.2` |
| Thiết bị thấy được | Windows, Chrome, Edge; không có Android emulator/thiết bị kết nối |
| Android | SDK có sẵn nhưng còn license chưa chấp nhận |
| Tài liệu yêu cầu | `../apptruyen.docx`, có UC01–UC29 |
| AGENTS.md | Không tìm thấy trong các thư mục dự án đã rà soát |
| Database | Có schema tại `database/novi_schema_v1.sql` và bản DB riêng tại `../NVTDuong_AppReadBook_DB`; migration `002_publishing.sql`, `003_personal_reading.sql`, `004_read_rankings.sql` nằm trong `../NVTDuong_AppReadBook_DB/migrations` |

### 1.2. Giới hạn đối chiếu

- Truy cập được đầy đủ source Flutter, backend và `apptruyen.docx`.
- Không có connection string/JWT key đang cấu hình trong `appsettings*.json`; bí mật phải cấp qua biến môi trường hoặc user-secrets. Vì chưa xác minh runtime connection hiện tại trỏ đúng `novi_test`, **không chạy lại integration test có ghi database** trong đợt rà soát này.
- Không chạy SMTP thật, Firebase thật, Android emulator hoặc thiết bị thật.
- Các file ma trận cũ cho biết publishing, personal reading, ranking, Local Media và Windows E2E từng PASS trên `novi_test`; báo cáo ghi rõ đó là kết quả trước đây.
- Schema có các bảng Donate, báo cáo và tương đồng nhưng chưa tìm thấy controller/service/repository nghiệp vụ tương ứng. Bảng dữ liệu đơn lẻ không được tính là chức năng hoàn chỉnh.

### 1.3. Kết luận nhanh

**Luồng đã có mã nguồn và có bằng chứng chạy:** đăng ký/đăng nhập JWT, hồ sơ, đăng xuất/lưu token, khám phá/tìm kiếm/lọc truyện, chi tiết/chương/trình đọc, tiến độ/lịch sử/Đọc tiếp, tủ sách, BXH, publishing/kiểm duyệt backend, upload Media Local và theme sáng/tối.

**Có mã nguồn nhưng chưa xác minh đầu-cuối trong lần này:** OTP email, đổi mật khẩu, toàn bộ publishing qua Flutter (chưa có UI), Local Media qua UI Flutter, Firebase, Android và triển khai HTTPS production.

**Thiếu để demo toàn bộ tài liệu:** quản lý người dùng, giao diện tác giả/admin, Donate, báo cáo nội dung và xử lý báo cáo, tương đồng, thống kê, audio/TTS, offline và quản lý thể loại admin.

Để demo ổn định ngay, cần cấu hình backend vào `novi_test`, chọn profile HTTP phù hợp hoặc HTTPS hợp lệ, truyền đúng `API_BASE_URL`, dùng `Media__Provider=Local`, sau đó chạy checklist ưu tiên ở phần 4.

## 2. Ma trận đối chiếu yêu cầu UC01–UC29

Trạng thái Backend/Flutter: **Đã triển khai / Một phần / Chưa tìm thấy / Chưa xác định**. Trạng thái test: **PASS / FAIL / Chưa chạy / Bị chặn**.

| Mã UC | Chức năng | Backend | Flutter | Bằng chứng trong repo | Kết quả kiểm thử | Phần còn thiếu |
|---|---|---|---|---|---|---|
| UC01 | Đăng ký | Đã triển khai | Đã triển khai | `AuthController.Register`, `AuthService.RegisterAsync`, `RegisterRequest`; `lib/ui/auth_sheet.dart`, `Session.register` | PASS lần này ở widget; PASS backend thật trước đây trong `integration_test/auth_flow_test.dart` | Tài liệu nói có trường hợp chọn vai trò nhưng DTO chỉ tạo role độc giả. Quy trình thực tế là đăng ký độc giả rồi gửi `POST /api/author-applications`, không chọn role lúc đăng ký. |
| UC02 | Đăng nhập | Đã triển khai | Đã triển khai | `AuthController.Login`, JWT trong `Program.cs`; `AuthSheet`, `Session.login`, `flutter_secure_storage` | PASS lần này ở widget; PASS backend thật trước đây | Cần test lại runtime thực tế sau khi thống nhất HTTP/HTTPS và DB. |
| UC03 | Quản lý thông tin cá nhân | Đã triển khai | Đã triển khai | `UsersController.GetProfile/UpdateProfile`; `ProfilePage`, `editProfile`, `Session.updateProfile` | PASS (Windows E2E trước đây) | Avatar upload có backend nhưng chưa thấy UI upload Flutter. |
| UC04 | Đổi mật khẩu | Đã triển khai | Chưa tìm thấy | `PUT /api/users/me/password`, `ChangePasswordRequest`, `AuthService.ChangePasswordAsync` | Chưa chạy | Cần form Flutter, validation và E2E đổi mật khẩu/đăng nhập lại. |
| UC05 | Quên mật khẩu | Đã triển khai | Chưa tìm thấy | `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`, `SmtpEmailSender`, bảng `password_reset` | Bị chặn | Thiếu UI Flutter; SMTP/OTP email thật chưa được cấu hình và chạy xác minh. |
| UC06 | Đăng xuất | Một phần | Đã triển khai | JWT access token không có revoke endpoint; `Session.logout/_clear` xóa token, expiry và user khỏi secure storage | PASS (Windows E2E trước đây) | Nếu yêu cầu hủy token server-side cần blacklist/revocation; hiện là JWT stateless phía client. |
| UC07 | Quản lý người dùng | Chưa tìm thấy | Chưa tìm thấy | Có `user.status/role` trong schema và kiểm tra account active, nhưng không có admin user controller/list/lock/unlock | Chưa chạy | Cần API, phân quyền, audit, UI admin và test khóa/mở khóa. |
| UC08 | Tìm kiếm truyện | Đã triển khai | Đã triển khai | `GET /api/novels` với keyword/category trong `NovelsController.Search`; Home/Search UI trong `lib/ui/screens.dart` | PASS (Windows E2E trước đây) | Cần chạy lại với backend hiện tại và dữ liệu demo. |
| UC09 | Khám phá truyện | Đã triển khai | Đã triển khai | `NovelRepository.SearchPublicAsync`, `GET /api/categories`; `HomePage`, chip thể loại, phân trang | PASS (Windows E2E trước đây) | Chưa có đề xuất cá nhân; UI hiện là khám phá/dữ liệu cập nhật thật. |
| UC10 | Xem chi tiết truyện | Đã triển khai | Đã triển khai | `NovelsController.Detail/Chapters`; `NovelDetailPage` | PASS (Windows E2E trước đây) | Kiểm tra lại trường thể loại ở chi tiết nếu yêu cầu hiển thị đầy đủ. |
| UC11 | Đọc truyện | Đã triển khai | Đã triển khai | Public chapter route; `PersonalReadingController` session/progress/view/continue; `ReaderPage` | PASS (backend personal-reading và Windows E2E trước đây) | Android/back-resume, mất mạng, token hết hạn thật và HTTP 409 UI còn ca chưa chạy. |
| UC12 | Quản lý thư viện cá nhân | Đã triển khai | Đã triển khai | `/api/me/library`, `/api/me/history`; `LibraryPage`, `HistoryPage`, `ContinueReadingBar` | PASS (backend và Windows E2E trước đây) | UI phân trang >20 và bỏ lưu lặp chưa được tự động hóa đầy đủ trên Flutter. |
| UC13 | Đăng tải truyện | Đã triển khai | Chưa tìm thấy | `POST /api/author/novels`, `PublishingRepository.CreateNovelAsync`; schema/migration publishing | PASS backend trước đây | Cần UI tác giả, chọn thể loại (request hiện chưa thể hiện category IDs) và upload bìa từ Flutter. |
| UC14 | Quản lý thông tin truyện | Đã triển khai | Chưa tìm thấy | GET/PUT/visibility/DELETE `/api/author/novels`; `novel_revision` | PASS backend trước đây | Cần UI tác giả và kiểm tra liên kết thể loại trong form. |
| UC15 | Quản lý chương truyện | Đã triển khai | Chưa tìm thấy | GET/POST chapter, PUT/visibility/DELETE author routes; `chapter_revision` | PASS backend trước đây | Cần UI tác giả và editor chương. |
| UC16 | Thực hiện Donate | Một phần | Chưa tìm thấy | Chỉ có bảng `donation`, `donation_event` trong schema; không tìm thấy API/gateway service | Chưa chạy | Cần chốt phạm vi A/B trong tài liệu, API tạo giao dịch/callback, tích hợp cổng và UI. |
| UC17 | Xem lịch sử Donate | Một phần | Chưa tìm thấy | Bảng `donation` có donor/status/time nhưng không có endpoint lịch sử | Chưa chạy | Cần repository/controller, phân trang, UI và test cách ly tài khoản. |
| UC18 | Duyệt tác phẩm | Đã triển khai | Chưa tìm thấy | `/api/admin/moderation`, decision route; transaction, audit `moderation_decision`, chống tự duyệt/xung đột | PASS backend trước đây | Cần UI admin và chạy lại integration trên `novi_test`. |
| UC19 | Duyệt chương | Đã triển khai | Chưa tìm thấy | Chung moderation queue/decision; `DecideChapter`, `DecideChapterRevision` | PASS backend trước đây | Cần UI admin và chạy lại integration. |
| UC20 | Xử lý báo cáo nội dung | Một phần | Chưa tìm thấy | Chỉ có bảng `content_report`; không tìm thấy report controller/service | Chưa chạy | Cần danh sách/chi tiết/decision, ẩn nội dung, audit và UI admin. |
| UC21 | Kiểm tra nội dung tương đồng | Một phần | Chưa tìm thấy | Chỉ có bảng `similarity_check`, `similarity_match` | Chưa chạy | Cần thuật toán/service/job/API, lưu kết quả và test chất lượng. |
| UC22 | Xem kết quả tương đồng | Một phần | Chưa tìm thấy | Schema có cột phần trăm/match, không có query API/UI | Chưa chạy | Cần endpoint danh sách/chi tiết và UI admin. |
| UC23 | Theo dõi hoạt động tác phẩm | Một phần | Chưa tìm thấy | Author có danh sách tác phẩm; public DTO có `ViewCount/LibraryCount`, nhưng chưa có dashboard/activity endpoint riêng | Chưa chạy | Cần chỉ số theo thời gian, phạm vi “mức độ quan tâm”, UI tác giả và test. |
| UC24 | Theo dõi Donate nhận được | Một phần | Chưa tìm thấy | Bảng donation có `recipient_id`, amount/status; không có endpoint tổng hợp | Chưa chạy | Cần API tổng tiền/danh sách, UI tác giả và quy tắc fee/phạm vi chuyển tiền. |
| UC25 | Thống kê hoạt động hệ thống | Chưa tìm thấy | Chưa tìm thấy | Không tìm thấy admin statistics controller/service/screen | Chưa chạy | Cần định nghĩa KPI, khoảng thời gian, API tổng hợp, UI và test. |
| UC26 | Nghe truyện bằng audio | Chưa tìm thấy | Chưa tìm thấy | Không có audio/TTS package, API hoặc màn hình | Chưa chạy | Tài liệu gợi ý TTS thiết bị; cần chọn package, play/pause/rate/voice và test nền tảng. |
| UC27 | Tải truyện đọc offline | Chưa tìm thấy | Chưa tìm thấy | Không có kho nội dung offline/download manager | Chưa chạy | Cần cache có phiên bản/quyền truy cập, quản lý dung lượng và UI tải/xóa. |
| UC28 | Báo cáo nội dung (độc giả) | Một phần | Chưa tìm thấy | Bảng `content_report` và unique pending constraint; không có API gửi report | Chưa chạy | Cần API kiểm tra target/reason/duplicate, UI tại chi tiết/trình đọc và nối UC20. |
| UC29 | Quản lý thể loại | Một phần | Chưa tìm thấy | Public `GET /api/categories`; schema có `is_active`; legacy `/Category` bị chặn HTTP 410 | Chưa chạy | Cần API admin thêm/sửa/ẩn, chống trùng/xóa thể loại đang dùng, UI admin; form tác giả phải dùng cùng API. |

### 2.1. Chức năng bổ sung ngoài UC01–UC29

| Chức năng bổ sung | Backend | Flutter | Bằng chứng | Test |
|---|---|---|---|---|
| Yêu cầu nâng quyền tác giả | Đã triển khai | Chưa tìm thấy | `POST /api/author-applications`, admin application queue/decision | PASS backend trước đây |
| Revision và lịch sử kiểm duyệt | Đã triển khai | Chưa tìm thấy | `novel_revision`, `chapter_revision`, `moderation_decision`; transaction/concurrency | PASS backend trước đây |
| BXH lượt đọc | Đã triển khai | Đã triển khai | `GET /api/novels/rankings`, `RankingScreen`, top 9 Trang chủ | PASS backend/Windows trước đây; widget hiện tại PASS |
| Media Local/Firebase provider | Đã triển khai | Một phần | `MediaController`, `IMediaStorage`, Local/Firebase provider; Flutter chỉ đọc URL/placeholder, chưa có upload UI | Local PASS trước đây; Firebase thật Bị chặn |
| Theme sáng/tối/theo hệ thống | Không áp dụng | Đã triển khai | `NoviThemeController`, ThemeData/ColorScheme, Hồ sơ → Giao diện | PASS widget lần này và Windows trước đây |
| Chống đếm trùng lượt đọc | Đã triển khai | Đã triển khai | `chapter_view`, `RecordViewAsync`, session/sequence/generation logic | PASS backend/Windows trước đây |

### 2.2. Tổng hợp 29 UC

**Theo mức triển khai tổng thể (kết hợp backend + Flutter):**

- Đã triển khai: **9/29** — UC01, UC02, UC03, UC06, UC08, UC09, UC10, UC11, UC12.
- Một phần: **16/29** — UC04, UC05, UC13–UC24 (trừ UC25), UC28, UC29.
- Chưa tìm thấy: **4/29** — UC07, UC25, UC26, UC27.
- Chưa xác định: **0/29**.

**Theo bằng chứng kiểm thử chức năng:**

- PASS (gồm kết quả trước đây có ma trận): **14/29** — UC01, UC02, UC03, UC06, UC08–UC15, UC18, UC19.
- FAIL: **0/29**.
- Chưa chạy: **14/29**.
- Bị chặn: **1/29** — UC05 do thiếu UI và chưa cấu hình SMTP thật.

Tổng kiểm tra: `14 + 0 + 14 + 1 = 29`.

## 3. Kết quả kiểm tra thực tế

### 3.1. Lệnh đã chạy trong đợt rà soát

| Lệnh | Kết quả thực tế |
|---|---|
| `dotnet --version` | PASS — `8.0.403` |
| `dotnet build ReadBook.sln -c Release --no-restore` | FAIL thao tác — file solution này không tồn tại; không phải lỗi source |
| `dotnet build ReadBookApi.sln -c Release --no-restore` | PASS — 0 warning, 0 error |
| `flutter --version` | PASS — Flutter 3.35.3, Dart 3.9.2 |
| `flutter devices` | PASS — Windows, Chrome, Edge; không có Android device |
| `flutter doctor -v` | Một phần — Windows toolchain PASS; Android SDK có nhưng còn license chưa chấp nhận |
| `flutter analyze` | Hoàn tất — **40 warning/info**, không có compile error; chủ yếu ở prototype cũ và dự án lồng `FE/flutter_application_1` |
| `flutter test` | PASS — **15 passed, 0 failed, 0 skipped** |
| `flutter build windows --release --dart-define=API_BASE_URL=http://localhost:5148` | PASS — artifact `build/windows/x64/runner/Release/flutter_application_1.exe` |

Không chạy integration DB/API trong lần này. Lý do: connection string và JWT key không được cấu hình trong file, và chưa xác minh một runtime hiện hành trỏ chính xác `novi_test`. Không chạy MySQL migration, email SMTP, Firebase, Android hoặc UI Windows tương tác thật.

### 3.2. Bằng chứng kiểm thử trước đây trong repo

- `../NVTDuong_AppReadBook_BE-/ReadBook/tests/PUBLISHING_TEST_MATRIX.md`: publishing PASS trên `novi_test`, gồm ownership, revision, self-review và concurrency 204/409.
- `../NVTDuong_AppReadBook_BE-/ReadBook/tests/PERSONAL_READING_TEST_MATRIX.md`: library/history/progress/view PASS; Firebase thật BLOCKED.
- `../NVTDuong_AppReadBook_BE-/ReadBook/tests/MEDIA_TEST_MATRIX.md`: Local Media upload thật PASS trên `novi_test`; Firebase thật BLOCKED.
- `../NVTDuong_AppReadBook_BE-/ReadBook/tests/RANKING_TEST_MATRIX.md`: boundary tuần/tháng, filter, pagination, tie và query/index PASS.
- `FLUTTER_E2E_TEST_MATRIX.md`: Windows reader E2E PASS phần lớn; các ca >20 tủ sách, mất backend, 409 UI, token hết hạn thật và soft-delete UI còn NOT RUN.
- `RANKING_FLUTTER_TEST_MATRIX.md`, `DEMO_THEME_TEST_MATRIX.md`: BXH, theme và demo media từng PASS trên Windows.

### 3.3. Cấu hình chạy thực tế trong repo

**Backend**

- HTTP profile: `http://localhost:5148`.
- HTTPS profile: `https://localhost:7112;http://localhost:5148`.
- `Program.cs` gọi `UseHttpsRedirection()` không điều kiện. Khi chạy profile HTTPS nhưng Flutter gọi HTTP, POST có thể nhận **307**. Để dev Windows ổn định, chạy profile `http` hoặc dùng HTTPS hợp lệ và cấu hình client tương ứng.
- Backend yêu cầu `ConnectionStrings__Default` và JWT key ít nhất 32 byte; Development có guard buộc database là `novi_test`.
- `appsettings.json` để connection string/JWT key rỗng; không có secret bị ghi trong báo cáo này.
- `Media.Provider` mặc định trong appsettings là Firebase. Muốn demo không cần billing phải đặt `Media__Provider=Local`, cấu hình Local root/public base URL theo `README_MEDIA_STORAGE.md`.

Lệnh khuyến nghị (giá trị bí mật tự cấu hình, không lưu trong source):

```powershell
cd "..\NVTDuong_AppReadBook_BE-\ReadBook\ReadBookApi"
# Thiết lập ConnectionStrings__Default trỏ novi_test và Jwt__Key qua user-secrets/env.
$env:Media__Provider = 'Local'
dotnet run --launch-profile http
```

**Flutter**

- `ApiClient.baseUrl` lấy từ `--dart-define=API_BASE_URL=...`.
- Mặc định là `http://10.0.2.2:5148`, chỉ phù hợp Android Emulator; Windows phải truyền `http://localhost:5148`.
- Android debug cho phép cleartext trong `android/app/src/debug/AndroidManifest.xml`; main/release không bật cleartext.

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5148
flutter run -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:5148
```

## 4. Checklist để tự kiểm thử

Hai cột **Kết quả thực tế** và **Pass/Fail** được để trống để điền khi test.

### 4.1. Luồng kiểm thử trên Flutter

| ID | Luồng | Vai trò và dữ liệu chuẩn bị | Các bước | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|---|---|---|---|---|---|---|
| F01 | Đăng ký hợp lệ/lỗi | Email mới; email đã tồn tại | Mở Hồ sơ → Đăng nhập/Đăng ký; thử trống, email sai, mật khẩu <8, xác nhận khác; sau đó đăng ký hợp lệ | Lỗi nằm đúng dưới trường; không gửi form sai; tài khoản hợp lệ được tạo và đăng nhập |  |  |
| F02 | Đăng nhập sai/đúng | Tài khoản active | Thử mật khẩu sai rồi đúng | Sai trả “Email hoặc mật khẩu không đúng”; đúng vào được hồ sơ |  |  |
| F03 | Tài khoản khóa | Một user có status inactive trong `novi_test` | Đăng nhập user khóa | Hiển thị tài khoản bị khóa, không lưu token |  |  |
| F04 | Hồ sơ và đổi tài khoản | Hai tài khoản reader | Sửa hồ sơ A, đăng xuất, đăng nhập B | Hồ sơ cập nhật; dữ liệu/token A không lẫn sang B |  |  |
| F05 | Tìm và lọc truyện | Có truyện public nhiều thể loại | Tìm theo tên/tác giả; chọn/bỏ thể loại; tải trang sau | Kết quả đúng API, không trùng/mất item |  |  |
| F06 | Chi tiết và đọc khách | Truyện/chương public | Không đăng nhập; mở chi tiết, chương 1, chuyển trước/sau | Đọc được; không tạo progress/session cá nhân |  |  |
| F07 | Tiến độ và Đọc tiếp | Reader đăng nhập; truyện ≥2 chương dài | Mở chương, cuộn, đổi font/nền, chuyển chương, thoát và mở lại app; bấm Đọc tiếp | Đúng chương/vị trí; không ghi progress=0 khi restore; không tạo request lặp |  |  |
| F08 | Tủ sách hai tài khoản | Reader A/B | A lưu truyện; kiểm tra tủ sách; logout sang B; bỏ lưu lặp | A thấy truyện, B không thấy; thao tác lặp không lỗi/trùng |  |  |
| F09 | Lịch sử và unavailable | Reader đã đọc; sau đó admin ẩn chapter fixture | Mở lịch sử trước/sau khi ẩn | Chỉ lịch sử user hiện tại; item ẩn báo không khả dụng và không mở nội dung |  |  |
| F10 | BXH | Có chapter_view hợp lệ ở nhiều kỳ/thể loại | Từ icon Trang chủ mở BXH; đổi Tuần/Tháng/Tất cả, category/Hoàn thành, load more, quay lại | Rank/count/filter đúng; top 9 mở chi tiết; mở BXH không tạo view |  |  |
| F11 | Theme và màn hình hẹp | Khách hoặc reader | Chọn Sáng/Tối/Hệ thống; restart; thử cửa sổ 360×800 | Theme được lưu, không overflow, trình đọc giữ nền riêng |  |  |
| F12 | Lỗi kết nối/307 | Backend dừng; sau đó chạy sai profile HTTPS | Thử login/search; bật lại backend HTTP | Lỗi mạng dễ hiểu; không vòng lặp; không còn 307 khi dùng đúng profile/URL |  |  |

### 4.2. Luồng phải kiểm thử bằng Swagger/API

| ID | Luồng | Vai trò và dữ liệu chuẩn bị | Các bước | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|---|---|---|---|---|---|---|
| A01 | Preflight an toàn | MySQL login có quyền test | Xác minh `SELECT DATABASE()`; chỉ tiếp tục nếu là `novi_test`; áp schema/migration theo thứ tự | Không ghi vào `novi`; schema/migration thành công/idempotent theo hướng dẫn |  |  |
| A02 | Upload avatar Local | Reader active, PNG/JPEG/WebP hợp lệ và file giả/quá cỡ | Đặt Local provider; POST `/api/media/avatar`; kiểm tra URL HTTP và `user.avatar_url` | File hợp lệ đọc được; giả/quá cỡ bị chặn; tên ngẫu nhiên |  |  |
| A03 | Upload bìa Local/revision | Author sở hữu một draft và một novel published | POST cover cho draft/published; thử sai owner và pending revision | Draft cập nhật trực tiếp; published tạo revision, bản public vẫn cũ; 404/409 đúng |  |  |
| A04 | Yêu cầu làm tác giả | Reader và admin | Reader POST `/api/author-applications`; admin xem queue, reject có lý do; reader gửi lại; admin approve | Role chỉ đổi sau approve; lịch sử reviewer/time/reason đúng |  |  |
| A05 | Tạo và duyệt truyện | Author, admin khác owner | Tạo novel; gọi public; reject, sửa/gửi lại, approve | Trước duyệt public 404; sau approve public thấy bản đã duyệt |  |  |
| A06 | Tạo và duyệt chương | Novel đã duyệt; author/admin | Tạo chapter, kiểm tra public, reject/resubmit/approve | Chương chỉ public sau duyệt; truyện cha ẩn thì chapter cũng không đọc được |  |  |
| A07 | Revision truyện | Novel public có tiêu đề A | Author PUT thành B; độc giả GET trước duyệt; admin approve/reject; GET lại | **Trước duyệt độc giả vẫn thấy A**; approve mới thấy B; reject giữ A |  |  |
| A08 | Revision chương | Chapter public có nội dung A | Author PUT nội dung B; GET public trước/sau decision | Trước duyệt vẫn A; approve mới B; reject giữ A |  |  |
| A09 | Ownership/tự duyệt/concurrency | Hai author, một admin và tác phẩm admin-owned | Author B sửa tác phẩm A; admin tự duyệt; gửi hai quyết định đồng thời | Sai owner 404/403; tự duyệt 403; concurrency đúng một 204 và một 409, một audit row |  |  |
| A10 | Reading contract | Hai reader, novel/chapter public | Begin session, update sequence đảo thứ tự, dùng session của user khác, gọi view đồng thời | Request cũ không ghi đè; session cách ly; view chỉ tăng một trong cửa sổ |  |  |
| A11 | Public filtering | Pending/hidden/deleted novel và chapter | Gọi list/detail/chapter/session/progress/view/continue | Không lộ nội dung; continue trả unavailable phù hợp |  |  |
| A12 | Ranking boundaries | Fixture view trước/sau đầu tuần/tháng VN | Gọi `/api/novels/rankings` với period/filter/page | Boundary Asia/Ho_Chi_Minh, tie, rank liên tục, không nhân view nhiều category |  |  |

## 5. Công việc còn lại theo thứ tự ưu tiên

| Ưu tiên | Việc cần làm tiếp | Lý do/ảnh hưởng demo | Tiêu chí xác nhận hoàn thành |
|---|---|---|---|
| P0 | Chuẩn hóa một quy trình chạy `novi_test` | Hiện dễ gặp 307, thiếu DB/JWT hoặc mặc định Firebase | Script/preflight không lộ secret; xác minh DB=`novi_test`; backend HTTP 5148 hoặc HTTPS chuẩn; Flutter đúng `API_BASE_URL`; Local Media hoạt động |
| P0 | Chạy lại checklist demo end-to-end | Nhiều PASS là kết quả 30/10, không phải lần hiện tại | F01–F12 và A01–A12 có bằng chứng mới, fixture cô lập và cleanup |
| P1 | Làm Flutter tác giả/admin | Backend publishing tốt nhưng người dùng không thao tác được qua app | UI apply-author, CRUD novel/chapter, moderation/revision; ownership và trạng thái đầy đủ; E2E PASS |
| P1 | Hoàn thiện đổi/quên mật khẩu từ API đến UI | UC04/UC05 đang đứt ở Flutter; SMTP chưa xác minh | Form Flutter, validation, OTP email thật trên test SMTP, đăng nhập bằng mật khẩu mới PASS |
| P1 | Quản lý người dùng và thể loại | Hai UC admin quan trọng chưa có API/UI | List/search/lock/unlock user và add/edit/hide category có audit, phân quyền, test |
| P2 | Báo cáo nội dung + xử lý báo cáo | UC28 là đầu vào bắt buộc cho UC20 | Reader gửi report; admin xử lý; duplicate/ẩn nội dung/audit PASS |
| P2 | Donate | UC16/17/24 mới chỉ có schema | Chốt phạm vi A/B; sandbox gateway/callback idempotent; lịch sử donor/recipient và UI PASS |
| P2 | Dashboard hoạt động/thống kê | UC23/25 chưa đủ | API theo kỳ + UI tác giả/admin, định nghĩa KPI và test query |
| P3 | Tương đồng | Hiện chỉ có schema | Thuật toán và ngưỡng được mô tả; API/job/UI; test dữ liệu chuẩn và lưu kết quả |
| P3 | Audio TTS và offline | UC26/27 chưa có | TTS play/pause/rate hoạt động; offline download/version/delete hoạt động trên Android/Windows theo phạm vi |
| P3 | Android và production hardening | Android chưa chạy, production config chưa xác minh | Chấp nhận license bởi người dùng, emulator/device E2E PASS; HTTPS, CORS, secret store, logging và backup/deploy checklist hoàn tất |
| P3 | Tách/dọn prototype cũ | Analyzer còn 40 warning/info và có project Flutter lồng | Xác định entrypoint duy nhất; không còn import/data giả trong build chính; analyzer mã production sạch |

### Điểm chốt tiến độ

- **29 UC tài liệu:** 9 đã triển khai, 16 một phần, 4 chưa tìm thấy.
- **Kiểm thử 29 UC:** 14 có bằng chứng PASS (một số là kết quả trước đây), 14 chưa chạy, 1 bị chặn, 0 FAIL được ghi nhận.
- **Chức năng bổ sung:** publishing revision, nâng quyền tác giả, BXH, Media provider, theme và chống đếm view có source rõ; UI tác giả/admin và Firebase thật vẫn chưa hoàn chỉnh/xác minh.

