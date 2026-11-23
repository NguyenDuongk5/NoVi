const KEY = 'novi_admin_session'

export const adminSession = {
  get() {
    try {
      const value = JSON.parse(localStorage.getItem(KEY) || 'null')
      if (!value?.accessToken || !value?.user) return null
      if (value.expiresAtUtc && new Date(value.expiresAtUtc) <= new Date()) {
        this.clear()
        return null
      }
      return value
    } catch {
      this.clear()
      return null
    }
  },
  set(value) { localStorage.setItem(KEY, JSON.stringify(value)) },
  clear() { localStorage.removeItem(KEY) },
}
