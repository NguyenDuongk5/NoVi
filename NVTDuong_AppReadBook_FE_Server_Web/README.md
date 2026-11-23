# NoVi Web Admin

Web Vue 3 dành riêng cho quản trị viên NoVi. Các chức năng đọc truyện và quản lý tác phẩm của tác giả nằm trong ứng dụng Flutter.

## Chạy local

Backend mặc định: `http://localhost:5148`. Có thể đổi bằng biến môi trường Vite:

```powershell
$env:VITE_API_BASE_URL='http://localhost:5148'
npm install
npm run dev
```

Mở URL Vite in ra terminal (thường là `http://localhost:5173`). Backend Development cho phép CORS từ localhost.

## Chức năng

- Đăng nhập/đăng xuất bằng `POST /api/auth/login`; chỉ chấp nhận `user.role = 2`.
- Hàng chờ yêu cầu tác giả: `/api/admin/author-applications`.
- Hàng chờ truyện, chương và revision: `/api/admin/moderation`.
- Route quản trị được bảo vệ; HTTP 401 xóa phiên local, HTTP 403 được hiển thị theo ngữ cảnh, HTTP 409 tải lại hàng chờ.

Token chỉ được giữ trong local storage của cổng quản trị hiện tại. Không đưa mật khẩu, JWT key hoặc connection string vào `.env` được commit. Khi triển khai production, cấu hình HTTPS và chính sách lưu phiên phù hợp hạ tầng thực tế.

Các route Manga/Chapter/Category prototype cũ không còn được gắn vào router hoặc menu vì backend hiện trả 410 cho quy trình CRUD cũ.

## Build

```powershell
npm run build
```
