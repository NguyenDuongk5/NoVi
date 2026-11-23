export function apiMessage(error, fallback = 'Không thể thực hiện yêu cầu.') {
  const data = error?.response?.data
  if (typeof data === 'string' && data.trim()) return data
  if (data?.message) return data.message
  if (data?.detail) return data.detail
  if (data?.title) return data.title
  if (error?.code === 'ECONNABORTED') return 'Máy chủ phản hồi quá chậm. Vui lòng thử lại.'
  if (!error?.response) return 'Không thể kết nối máy chủ. Vui lòng kiểm tra backend.'
  if (error.response.status >= 500) return 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.'
  return fallback
}
