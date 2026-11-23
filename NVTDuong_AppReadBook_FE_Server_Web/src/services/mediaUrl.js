import api from '../api/axiosClient'

const fallbackCover = '/placeholder-cover.svg'

export function mediaUrl(value) {
  if (!value) return fallbackCover
  const url = String(value).trim()
  if (!url) return fallbackCover
  if (/^https?:\/\//i.test(url) || /^data:/i.test(url) || /^blob:/i.test(url)) return url
  const apiBase = api.defaults.baseURL || window.location.origin
  try {
    return new URL(url, apiBase.endsWith('/') ? apiBase : `${apiBase}/`).toString()
  } catch {
    return fallbackCover
  }
}

export function useCoverFallback(event) {
  const image = event.currentTarget
  if (image.dataset.fallbackApplied === '1') return
  image.dataset.fallbackApplied = '1'
  image.src = fallbackCover
}
