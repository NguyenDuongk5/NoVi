# Quyết định thiết kế cơ sở dữ liệu Novi

## Nguồn đầu vào

- Các dump cũ trong `NVTDuong_AppReadBook_DB` chỉ được xem là dữ liệu tham khảo.
- `read_book_chuan.sql` là nền gần nhất nhưng không được nạp thẳng vào môi trường mới.
- Schema đích dùng MySQL 8.x, `utf8mb4` và lưu thời gian theo UTC.
- Schema sạch được tạo trong database `novi`, tách khỏi database legacy
  `read_book`. Không chạy các lệnh `CREATE TABLE IF NOT EXISTS` của schema mới
  trực tiếp trong `read_book`, vì bảng cũ có thể dùng collation khác và làm khóa
  ngoại không tương thích.

## Thay đổi so với dữ liệu cũ

- Đổi thuật ngữ `manga` thành `novel` để đúng đề tài tiểu thuyết.
- Bỏ `list_category_id` và `list_manga_id`; quan hệ thể loại chỉ lưu tại `novel_category`.
- Bỏ `password_hint`; không lưu bất kỳ gợi ý nào có thể làm lộ mật khẩu.
- Bỏ các bảng ngoài báo cáo: `project`, `post`, bình luận và đánh giá.
- Bỏ bảng backup/orphan khỏi schema production.
- Tách lịch sử trạng thái Donate thành `donation_event` để đối soát callback an toàn.
- Dùng khóa ngoại cho người tạo/người duyệt thay cho các cột chuỗi `created_by`/`modified_by`.
- Giữ revision riêng cho truyện và chương để nội dung đang công khai không bị thay đổi trước khi quản trị viên duyệt.
- Báo cáo chỉ nhắm tới truyện hoặc chương trong MVP; tính hợp lệ của `target_id` được kiểm tra tại service vì quan hệ đa hình không thể biểu diễn bằng một khóa ngoại duy nhất.

## Quy ước trạng thái

Các giá trị số phải được định nghĩa lại bằng enum ở backend và không rải magic number trong code.

- `user.role`: 0 Reader, 1 Author/Translator, 2 Admin.
- `user.status`: 0 Locked, 1 Active.
- `review_status`: 0 Pending, 1 Approved, 2 Rejected.
- `visibility`: 0 Visible, 1 HiddenByOwner, 2 RemovedByAdmin.
- `novel.completion_status`: 0 Ongoing, 1 Completed, 2 Paused.
- `donation.status`: 0 Pending, 1 Succeeded, 2 Failed, 3 Cancelled, 4 Refunded.
- `content_report.status`: 0 Pending, 1 Accepted, 2 Rejected.

## Yêu cầu migration

- Chuyển dữ liệu từ `manga` sang `novel` và từ `manga_category` sang `novel_category`.
- Chỉ nhập các bản ghi không bị xóa và sửa URL ảnh `localhost` sang storage chính thức.
- Chuẩn hóa danh mục trùng tên Việt/Anh trước khi nhập.
- Không nhập dữ liệu test một ký tự, nội dung orphan hoặc ngày `0001-01-01`.
- Mật khẩu cũ chỉ được nhập nếu thực sự là hash mạnh; nếu không, buộc đặt lại mật khẩu.
