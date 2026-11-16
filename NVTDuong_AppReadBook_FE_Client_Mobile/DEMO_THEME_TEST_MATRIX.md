# Demo media và theme — 30/10/2026

| Ca kiểm thử | Kết quả | Bằng chứng |
|---|---|---|
| Seed lặp lại không sinh truyện/chương trùng | PASS | Chạy seed hai lần vẫn có 14 novel ID và 28 chapter ID duy nhất. |
| Nhãn nội dung minh họa | PASS | 14 mô tả và 28/28 chương có câu cảnh báo bắt buộc. |
| Không tạo view/lượt giả bằng seed | PASS | Sau khi dọn tài khoản E2E, `chapter_view` của toàn bộ demo trả `0`; seed không insert view/library. |
| API chi tiết trả đúng tên và URL tương đối | PASS | Windows integration runner kiểm tra truyện `9100…0001`. |
| Ảnh bìa đọc qua HTTP Media Local | PASS | `GET /uploads/test/demo-covers/ben-nhau-tron-doi.jpg` trả JPEG/200 khi backend nối `novi_test`. |
| Theme sáng/tối trên Trang chủ và BXH | PASS | Windows integration đổi theme, mở BXH và không có exception. |
| Đọc chương và chuyển chương | PASS | Windows UI thật mở “Khoảng cách trên trang giấy” rồi chuyển sang “Dấu trang cuối buổi”. |
| Lịch sử và tiếp tục đọc | PASS | Windows UI thật hiển thị lịch sử và tiếp tục đúng chương 2; DB trong lúc test: session=3, history=3, progress=1, view=2. Tài khoản/view test được dọn sau ca. |
| Lưu lựa chọn theme | PASS | Unit test SharedPreferences. |
| Bố cục BXH 360×800, chữ 160% | PASS | Widget regression test không overflow. |
| Flutter analyze phần đang dùng | PASS | `flutter analyze lib/main.dart lib/core lib/ui test/widget_test.dart`: no issues. |
| Flutter tests | PASS | 9/9. |
| Backend Release build | PASS | 0 warning, 0 error. |
| Windows debug build | PASS | `build/windows/x64/runner/Debug/flutter_application_1.exe`. |
| Ảnh chụp native Windows | PASS | `artifacts/screenshots/novi_home_light.png`, `novi_home_dark.png`, `novi_ranking_light.png`, `novi_ranking_dark.png`. |

Các thể loại “Chưa phân loại” được giữ có chủ đích vì bìa không đủ căn cứ. Không có kiểm thử Android trong lượt này.
