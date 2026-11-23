import { createRouter, createWebHistory } from 'vue-router'
import { adminSession } from '../services/adminSession'
import AdminLogin from '../views/AdminLogin.vue'
import AuthorApplications from '../views/AuthorApplications.vue'
import ModerationQueue from '../views/ModerationQueue.vue'
import NovelsAdmin from '../views/NovelsAdmin.vue'
import UsersAdmin from '../views/UsersAdmin.vue'
import CategoriesAdmin from '../views/CategoriesAdmin.vue'
import ContentReportsAdmin from '../views/ContentReportsAdmin.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: AdminLogin, meta: { public: true } },
    { path: '/', redirect: '/author-applications' },
    { path: '/author-applications', name: 'author-applications', component: AuthorApplications, meta: { title: 'Yêu cầu tác giả' } },
    { path: '/moderation', name: 'moderation', component: ModerationQueue, meta: { title: 'Kiểm duyệt nội dung' } },
    { path: '/novels', name: 'novels', component: NovelsAdmin, meta: { title: 'Quản lý truyện' } },
    { path: '/users', name: 'users', component: UsersAdmin, meta: { title: 'Người dùng' } },
    { path: '/categories', name: 'categories', component: CategoriesAdmin, meta: { title: 'Thể loại' } },
    { path: '/content-reports', name: 'content-reports', component: ContentReportsAdmin, meta: { title: 'Báo cáo nội dung' } },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

router.beforeEach((to) => {
  const session = adminSession.get()
  if (to.meta.public) return session?.user?.role === 2 ? '/' : true
  if (!session) return { name: 'login', query: { redirect: to.fullPath } }
  if (session.user?.role !== 2) {
    adminSession.clear()
    return { name: 'login', query: { forbidden: '1' } }
  }
  return true
})

export default router
