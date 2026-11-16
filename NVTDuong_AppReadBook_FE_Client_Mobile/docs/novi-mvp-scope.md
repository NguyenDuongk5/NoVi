# Phạm vi MVP của Novi

Tài liệu này chốt phạm vi triển khai từ báo cáo `doctruyen.docx`. Báo cáo là nguồn yêu cầu chức năng chính thức; ảnh NovelToon chỉ dùng tham khảo UX; màu hồng của ứng dụng cũ là màu thương hiệu.

## Nguyên tắc

- Chỉ xây dựng chức năng có trong phạm vi báo cáo.
- Mobile dành cho độc giả và tác giả/dịch giả; web dành cho quản trị viên.
- Không sao chép logo, nội dung, hình ảnh hoặc nhận diện của NovelToon.
- Không đưa vào MVP: truyện chat, mạng xã hội, VIP, cửa hàng, xu, phiếu đọc, sticker, cấp độ, audio, tải offline, bán truyện/chương, chatbot, dịch/tóm tắt bằng AI.

## Ma trận chức năng

| Nhóm | Chức năng MVP | Dữ liệu chính | API dự kiến |
|---|---|---|---|
| Tài khoản | Đăng ký, đăng nhập, đăng xuất | `user`, phiên/token | `/api/auth/*` |
| Mật khẩu | Đổi mật khẩu, quên mật khẩu qua OTP | `user`, `password_reset` | `/api/auth/password/*` |
| Hồ sơ | Xem/sửa họ tên và ảnh đại diện | `user` | `/api/users/me` |
| Khám phá | Truyện nổi bật, mới cập nhật, theo thể loại | `novel`, `category`, `chapter_view` | `/api/novels` |
| Tìm kiếm | Theo tên truyện, tác giả/dịch giả, thể loại | `novel`, `category` | `/api/novels/search` |
| Chi tiết truyện | Thông tin truyện và danh sách chương đã duyệt | `novel`, `chapter` | `/api/novels/{id}` |
| Đọc truyện | Đọc/chuyển chương, tùy chỉnh hiển thị ở thiết bị | `chapter` | `/api/chapters/{id}` |
| Tiến độ | Lưu vị trí và tiếp tục đọc | `reading_progress` | `/api/reading-progress` |
| Thư viện | Lưu/bỏ lưu truyện | `library_item` | `/api/library` |
| Lịch sử | Xem lịch sử đọc | `reading_history` | `/api/reading-history` |
| Tác giả | Đăng và sửa thông tin tác phẩm | `novel`, `novel_revision` | `/api/author/novels` |
| Chương | Thêm, sửa và quản lý chương | `chapter`, `chapter_revision` | `/api/author/chapters` |
| Theo dõi tác phẩm | Lượt đọc và mức độ quan tâm | `chapter_view`, `library_item` | `/api/author/statistics` |
| Donate | Tạo giao dịch, nhận callback, xem lịch sử | `donation`, `donation_event` | `/api/donations` |
| Báo cáo | Độc giả báo cáo truyện/chương | `content_report` | `/api/reports` |
| Kiểm duyệt | Duyệt/từ chối truyện và chương | revision + trạng thái nội dung | `/api/admin/reviews` |
| Tương đồng | Chạy và xem kết quả kiểm tra | `similarity_check`, `similarity_match` | `/api/admin/similarity-checks` |
| Quản trị | Khóa/mở tài khoản, thống kê | `user` và dữ liệu tổng hợp | `/api/admin/*` |

## Điều hướng mobile

Thanh điều hướng tham khảo bố cục NovelToon nhưng dùng màu hồng:

1. **Đề xuất**: khám phá, tìm kiếm, nổi bật, mới cập nhật và đọc tiếp.
2. **Phân loại**: thể loại, bộ lọc và sắp xếp.
3. **Tủ sách**: truyện đã lưu, đang đọc và lịch sử.
4. **Cá nhân**: hồ sơ, đổi mật khẩu, Donate và khu quản lý tác phẩm khi có quyền tác giả.

Không tạo tab mạng xã hội/`Theo dõi` kiểu bảng tin vì nằm ngoài phạm vi báo cáo.

## Thứ tự phát triển

1. Schema và hợp đồng API.
2. Xác thực và phân quyền.
3. Truyện, chương, thể loại, tìm kiếm và khám phá.
4. Đọc truyện, thư viện, lịch sử và tiến độ.
5. Công cụ tác giả và quy trình kiểm duyệt.
6. Donate, báo cáo và kiểm tra tương đồng.
7. Thống kê và hoàn thiện web quản trị.
