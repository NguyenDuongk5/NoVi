<template>
  <main class="login-page">
    <form class="login-card" @submit.prevent="submit">
      <div class="login-brand">NoVi</div>
      <h1>Đăng nhập quản trị</h1>
      <p>Chỉ tài khoản quản trị viên được phép truy cập.</p>
      <div v-if="message" class="notice error" role="alert">{{ message }}</div>
      <label>Email<input v-model.trim="email" type="email" autocomplete="username" required /></label>
      <label>Mật khẩu<input v-model="password" type="password" autocomplete="current-password" required /></label>
      <button class="button primary" :disabled="busy">{{ busy ? 'Đang đăng nhập…' : 'Đăng nhập' }}</button>
    </form>
  </main>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { authApi } from '../api/adminApi'
import { apiMessage } from '../services/apiError'
import { adminSession } from '../services/adminSession'

const route = useRoute(), router = useRouter()
const email = ref(''), password = ref(''), busy = ref(false)
const message = ref(route.query.expired ? 'Phiên đăng nhập đã hết hạn.' : route.query.forbidden ? 'Tài khoản không có quyền quản trị.' : '')

async function submit() {
  if (busy.value) return
  busy.value = true; message.value = ''
  try {
    const { data } = await authApi.login(email.value, password.value)
    if (data?.user?.role !== 2) {
      message.value = 'Tài khoản không có quyền quản trị.'
      return
    }
    adminSession.set(data)
    await router.replace(typeof route.query.redirect === 'string' ? route.query.redirect : '/')
  } catch (error) {
    if (error.response?.status === 401) message.value = 'Email hoặc mật khẩu không đúng.'
    else if (error.response?.status === 403) message.value = apiMessage(error, 'Tài khoản bị khóa hoặc không có quyền truy cập.')
    else message.value = apiMessage(error, 'Đăng nhập thất bại.')
  } finally { busy.value = false }
}
</script>

<style scoped>
.login-page{min-height:100vh;display:grid;place-items:center;padding:20px;background:linear-gradient(145deg,#fff7fa,#f8dce8)}
.login-card{width:min(430px,100%);background:white;border-radius:18px;padding:30px;box-shadow:0 20px 50px #74344f25}.login-brand{color:#d84d83;font-size:30px;font-weight:900}.login-card h1{margin-bottom:5px}.login-card p{color:#75666d}.login-card label{display:grid;gap:7px;margin:18px 0;font-weight:650}.login-card input{border:1px solid #d9c8d0;border-radius:10px;padding:12px}.login-card button{width:100%;margin-top:6px}
</style>
