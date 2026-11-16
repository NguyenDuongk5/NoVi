# Bộ bìa minh họa NoVi

`tooling/seed_demo_library.ps1` chỉ chấp nhận `novi_test`, sao chép ảnh vào Media Local và upsert 14 truyện cùng 28 chương bằng ID cố định. Mỗi truyện có hai chương tự sáng tác để thử trình đọc. Script không tạo lượt đọc, lượt lưu hoặc thứ hạng.

Mọi mô tả và chương đều bắt đầu bằng: **“Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.”** Nội dung chỉ mô tả thao tác hoặc bố cục thử nghiệm, không tóm tắt và không sao chép tác phẩm.

| Ảnh nguồn | Tên đọc trên bìa | Thể loại seed |
|---|---|---|
| Bên nhau trọn đời.jpg | Bên Nhau Trọn Đời | Ngôn tình |
| Chiếc bật lửa và váy công chúa.jpg | Chiếc Bật Lửa Và Váy Công Chúa | Ngôn tình |
| Khó dỗ dành.jpg | Khó Dỗ Dành | Ngôn tình |
| Miển thư.jpg | Miển Thư | Chưa phân loại |
| Một lít nước mắt.jpg | Một Lít Nước Mắt | Hồi ký |
| Nhật thực toàn phần.jpg | Nhật Thực Toàn Phần | Chưa phân loại |
| Nếu biết trăm năm là hữu hạn.jpg | Nếu Biết Trăm Năm Là Hữu Hạn | Tản văn |
| Trên đồi, mở mắt và mơ.jpg | Trên Đồi, Mở Mắt Và Mơ | Thiếu nhi |
| Trốn lên mái nhà để khóc.jpg | Trốn Lên Mái Nhà Để Khóc | Chưa phân loại |
| Tìm đến chốn bình yên.jpg | Tìm Đến Chốn Bình Yên | Chưa phân loại |
| Tăng hạ.jpg | Tăng Hạ | Chưa phân loại |
| Xuân khởi.jpg | Xuân Khởi | Ngôn tình |
| Đám trẻ ở đại dương đen.jpg | Đám Trẻ Ở Đại Dương Đen | Chưa phân loại |
| Đốt cháy.jpg | Đốt Cháy | Ngôn tình |

Các mục “Chưa phân loại” cần metadata từ người cung cấp; bìa không đủ căn cứ để suy ra thể loại. Tác giả, mô tả thật và nội dung chương không được suy đoán. `Miển Thư` giữ nguyên chính tả nhìn thấy trên bìa.

URL bìa lưu dạng tương đối (`/uploads/test/demo-covers/...`). Flutter ghép URL với `API_BASE_URL`, nên dùng đúng host backend trên Windows, Android Emulator hoặc thiết bị thật.

## Fixture cũ còn trong `novi_test`

Rà soát ngày 30/10/2026 còn thấy các nhóm tên `Flutter E2E …`, `Local Published …`, `Personal …`, `Other …` và một số `Publishing test …`. Đây là fixture của các bộ kiểm thử backend/Flutter trước, không thuộc 14 ID `novi-demo-*`. Seed này không sửa hoặc xóa chúng để không phá ma trận publishing/media/reading. Source Flutter đang dùng API thật; `lib/data/fake_data.dart` chỉ thuộc prototype cũ và không được import vào luồng `lib/main.dart` hiện hành.
