import api from './axiosClient'

let lastAdminNovelId = null

export const authApi = {
  login: (email, password) => api.post('/api/auth/login', { email, password }),
}

export const publishingAdminApi = {
  authorApplications: (page, pageSize) => api.get('/api/admin/author-applications', { params: { page, pageSize } }),
  decideAuthorApplication: (id, approve, reason) => api.post(`/api/admin/author-applications/${id}/decision`, { approve, reason }),
  moderationQueue: (page, pageSize) => api.get('/api/admin/moderation', { params: { page, pageSize } }),
  moderationDetail: (type, id) => api.get(`/api/admin/moderation/${encodeURIComponent(type)}/${id}`),
  decideModeration: (type, id, approve, reason) => api.post(`/api/admin/moderation/${encodeURIComponent(type)}/${id}/decision`, { approve, reason }),
}

export const administrationApi = {
  users: (params) => api.get('/api/admin/users', { params }),
  setUserStatus: (id, active) => api.patch(`/api/admin/users/${id}/status`, { active }),
  categories: (params) => api.get('/api/admin/categories', { params }),
  createCategory: (name) => api.post('/api/admin/categories', { name }),
  updateCategory: (id, name) => api.put(`/api/admin/categories/${id}`, { name }),
  setCategoryStatus: (id, active) => api.patch(`/api/admin/categories/${id}/status`, { active }),
  novels: (params) => api.get('/api/admin/novels', { params }),
  novel: (id) => { lastAdminNovelId = id; return api.get(`/api/admin/novels/${id}`) },
  novelChapter: (novelId, chapterId) => api.get(`/api/admin/novels/${novelId}/chapters/${chapterId}`),
  retryNovel: () => api.get(`/api/admin/novels/${lastAdminNovelId}`),
  setNovelVisibility: (id, active) => api.patch(`/api/admin/novels/${id}/visibility`, { active }),
}

export const contentReportsApi = {
  list: (params) => api.get('/api/admin/content-reports', { params }),
  decide: (id, accept, resolutionNote) => api.post(`/api/admin/content-reports/${id}/decision`, { accept, resolutionNote }),
}
