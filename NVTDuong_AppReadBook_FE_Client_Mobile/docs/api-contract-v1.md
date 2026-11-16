# Hợp đồng API Novi v1

Base path: `/api/v1`. JSON dùng `camelCase`; thời gian trả về theo ISO 8601 UTC. Danh sách phân trang dùng `page`, `pageSize` và trả về `items`, `page`, `pageSize`, `totalItems`, `totalPages`.

## Quy ước phản hồi

Phản hồi thành công trả dữ liệu trực tiếp trong `data`. Phản hồi lỗi có cấu trúc:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dữ liệu không hợp lệ",
    "details": {}
  }
}
```

Không trả stack trace, hash mật khẩu, OTP, payload callback thanh toán hoặc thông tin nội bộ.

## Xác thực và tài khoản

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| POST | `/auth/register` | Public | Đăng ký độc giả |
| POST | `/auth/login` | Public | Đăng nhập |
| POST | `/auth/refresh` | Public có refresh token | Cấp access token mới |
| POST | `/auth/logout` | Đã đăng nhập | Thu hồi phiên đăng nhập |
| POST | `/auth/forgot-password` | Public | Gửi OTP đặt lại mật khẩu |
| POST | `/auth/verify-reset-otp` | Public | Xác minh OTP |
| POST | `/auth/reset-password` | Public có reset token | Đặt mật khẩu mới |
| PUT | `/users/me/password` | Đã đăng nhập | Đổi mật khẩu |
| GET | `/users/me` | Đã đăng nhập | Lấy hồ sơ |
| PATCH | `/users/me` | Đã đăng nhập | Sửa họ tên/ảnh đại diện |

## Khám phá và đọc truyện

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/categories` | Public | Danh sách thể loại hoạt động |
| GET | `/novels` | Public | Danh sách mới/nổi bật, lọc và phân trang |
| GET | `/novels/search` | Public | Tìm theo từ khóa, tác giả và thể loại |
| GET | `/novels/{novelId}` | Public | Chi tiết truyện đã duyệt |
| GET | `/novels/{novelId}/chapters` | Public | Danh sách chương đã duyệt |
| GET | `/chapters/{chapterId}` | Public | Nội dung chương đã duyệt |
| POST | `/chapters/{chapterId}/views` | Public | Ghi nhận lượt đọc có chống trùng |

Các API public không được trả truyện/chương đang chờ duyệt, bị ẩn, bị gỡ hoặc đã soft delete.

## Thư viện và tiến độ

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/library` | Reader+ | Danh sách truyện đã lưu |
| PUT | `/library/{novelId}` | Reader+ | Lưu truyện |
| DELETE | `/library/{novelId}` | Reader+ | Bỏ lưu truyện |
| GET | `/reading-history` | Reader+ | Lịch sử đọc |
| DELETE | `/reading-history` | Reader+ | Xóa lịch sử của chính mình |
| GET | `/reading-progress/{novelId}` | Reader+ | Lấy vị trí đọc gần nhất |
| PUT | `/reading-progress/{novelId}` | Reader+ | Upsert chương và phần trăm đã đọc |

## Tác giả/dịch giả

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/author/novels` | Author+ | Danh sách tác phẩm của mình |
| POST | `/author/novels` | Author+ | Tạo và gửi truyện duyệt |
| GET | `/author/novels/{novelId}` | Chủ sở hữu | Xem bản quản lý |
| PATCH | `/author/novels/{novelId}` | Chủ sở hữu | Gửi bản sửa chờ duyệt |
| DELETE | `/author/novels/{novelId}` | Chủ sở hữu | Soft delete/ẩn tác phẩm |
| POST | `/author/novels/{novelId}/chapters` | Chủ sở hữu | Tạo chương chờ duyệt |
| PATCH | `/author/chapters/{chapterId}` | Chủ sở hữu | Gửi bản sửa chương |
| DELETE | `/author/chapters/{chapterId}` | Chủ sở hữu | Soft delete/ẩn chương |
| GET | `/author/novels/{novelId}/statistics` | Chủ sở hữu | Lượt đọc và số lượt lưu |
| GET | `/author/donations` | Author+ | Donate đã nhận |

Mọi truy vấn sửa/xóa phải kiểm tra `uploaderId` ở server, không tin `userId` do client gửi lên.

## Donate

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| POST | `/donations` | Reader+ | Khởi tạo Donate |
| GET | `/donations/{donationId}` | Người gửi/người nhận | Xem trạng thái |
| GET | `/donations/mine` | Reader+ | Lịch sử Donate đã gửi |
| POST | `/payments/{gateway}/callback` | Payment gateway | Callback có kiểm tra chữ ký và idempotency |

Client không tự đánh dấu giao dịch thành công. Trạng thái thành công chỉ được cập nhật sau callback hợp lệ hoặc bước đối soát server-to-server.

## Báo cáo và quản trị

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| POST | `/reports` | Reader+ | Báo cáo truyện/chương |
| GET | `/admin/users` | Admin | Danh sách người dùng |
| PATCH | `/admin/users/{userId}/status` | Admin | Khóa/mở tài khoản |
| GET | `/admin/reviews/novels` | Admin | Hàng đợi duyệt truyện |
| POST | `/admin/reviews/novels/{id}/decision` | Admin | Duyệt/từ chối truyện hoặc revision |
| GET | `/admin/reviews/chapters` | Admin | Hàng đợi duyệt chương |
| POST | `/admin/reviews/chapters/{id}/decision` | Admin | Duyệt/từ chối chương hoặc revision |
| GET | `/admin/reports` | Admin | Danh sách báo cáo |
| POST | `/admin/reports/{reportId}/decision` | Admin | Xử lý báo cáo |
| POST | `/admin/similarity-checks` | Admin | Bắt đầu kiểm tra tương đồng |
| GET | `/admin/similarity-checks/{checkId}` | Admin | Xem trạng thái/kết quả |
| GET | `/admin/statistics` | Admin | Thống kê người dùng, tác phẩm và lượt đọc |

## Các quy tắc bắt buộc

- Access token ngắn hạn; refresh token phải có cơ chế thu hồi phía server trước khi triển khai thật.
- Rate limit cho đăng nhập, gửi OTP, tìm kiếm, ghi nhận lượt xem, Donate và callback.
- Validate UUID, độ dài chuỗi, kích thước/định dạng ảnh và phạm vi phần trăm đọc.
- Endpoint danh sách phải phân trang và giới hạn `pageSize`.
- Tác vụ duyệt, khóa tài khoản, xử lý báo cáo và Donate phải có audit log ở tầng ứng dụng.
