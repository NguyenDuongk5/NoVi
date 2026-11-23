<template>
  <section class="page">
    <header class="page-header">
      <div><h1>Quản lý truyện</h1><p class="subtitle">Theo dõi trạng thái xuất bản và khả năng truy cập của toàn bộ truyện.</p></div>
      <button class="button" :disabled="loading" @click="load">Tải lại</button>
    </header>

    <form class="filters" @submit.prevent="applyFilters">
      <label>Tìm kiếm<input v-model="draft.keyword" placeholder="Tên truyện hoặc tác giả" /></label>
      <label>Thể loại<select v-model="draft.categoryId"><option value="">Tất cả</option><option v-for="category in categories" :key="category.categoryId" :value="category.categoryId">{{ category.name }}</option></select></label>
      <label>Duyệt<select v-model="draft.reviewStatus"><option value="">Tất cả</option><option value="0">Chờ duyệt</option><option value="1">Đã duyệt</option><option value="2">Từ chối</option></select></label>
      <label>Hiển thị<select v-model="draft.visibility"><option value="">Tất cả</option><option value="0">Công khai</option><option value="1">Tác giả ẩn</option><option value="2">Admin ẩn</option></select></label>
      <button class="button primary" :disabled="loading">Lọc</button>
    </form>

    <div v-if="message" class="notice" :class="{ error: messageError }" role="status">{{ message }} <button v-if="messageError" class="link-button" @click="load">Thử lại</button></div>
    <div class="card">
      <div v-if="loading && !items.length" class="empty">Đang tải truyện…</div>
      <div v-else-if="!items.length" class="empty">Không có truyện phù hợp.</div>
      <div v-else class="table-wrap">
        <table class="data-table novels-table"><thead><tr><th>Truyện</th><th>Tác giả</th><th>Thể loại</th><th>Chương</th><th>Trạng thái</th><th>Cập nhật</th><th></th></tr></thead>
          <tbody><tr v-for="item in items" :key="item.novelId" :data-novel-id="item.novelId">
            <td><div class="novel-cell"><img :src="cover(item.coverUrl)" alt="" @error="coverError"/><strong :title="item.title">{{ item.title }}</strong></div></td>
            <td>{{ item.authorName }}</td><td>{{ item.categories || 'Chưa phân loại' }}</td><td>{{ item.chapterCount }}</td>
            <td><div class="status-stack"><span class="status" :class="reviewClass(item.reviewStatus)">{{ reviewLabel(item.reviewStatus) }}</span><span class="status" :class="item.visibility === 0 ? 'approved' : 'rejected'">{{ visibilityLabel(item.visibility) }}</span><span v-if="item.hasPendingRevision" class="status pending">Bản sửa chờ duyệt</span></div></td>
            <td>{{ formatDate(item.updatedAt) }}</td>
            <td><div class="row-menu"><button class="icon-button" aria-label="Mở menu thao tác" @click="toggleMenu(item.novelId)">⋯</button><div v-if="menuId === item.novelId" class="row-dropdown"><button @click="openDetail(item)">Xem chi tiết</button><button :class="item.visibility === 0 ? 'danger-text' : ''" @click="openVisibility(item)">{{ item.visibility === 0 ? 'Ẩn truyện' : 'Hiện lại' }}</button></div></div></td>
          </tr></tbody>
        </table>
      </div>
      <AdminPager :page="page" :page-size="pageSize" :total="total" :busy="loading" @change="changePage" />
    </div>

    <div v-if="detailOpen" class="modal-backdrop" @click.self="closeDetail">
      <section ref="detailModal" class="modal wide novel-modal" role="dialog" aria-modal="true" aria-labelledby="novel-detail-title">
        <div class="detail-heading">
          <div><h2 id="novel-detail-title">{{ detail?.title || 'Chi tiết truyện' }}</h2><p v-if="detail">{{ detail.authorName }} · {{ detail.categories || 'Chưa phân loại' }}</p></div>
          <button class="icon-button" aria-label="Đóng" @click="closeDetail">×</button>
        </div>
        <div v-if="detailLoading" class="empty">Đang tải chi tiết…</div>
        <div v-else-if="detailError" class="detail-error"><h3>Không tải được chi tiết truyện</h3><p>{{ detailError }}</p><button class="button primary" @click="retryDetail">Thử lại</button></div>

        <template v-else-if="detail && chapterView">
          <button class="button back-button" @click="backToChapterList">← Quay lại danh sách chương</button>
          <div v-if="chapterLoading" class="empty">Đang tải nội dung chương…</div>
          <div v-else-if="chapterError" class="detail-error" role="alert"><h3>Không tải được nội dung chương</h3><p>{{ chapterError }}</p><button class="button primary" @click="retryChapter">Thử lại</button></div>
          <article v-else-if="chapterDetail" class="chapter-reader">
            <header><p class="chapter-kicker">Chương {{ chapterDetail.chapterNumber }}</p><h3>{{ chapterDetail.title }}</h3><div class="status-stack"><span class="status" :class="reviewClass(chapterDetail.reviewStatus)">{{ reviewLabel(chapterDetail.reviewStatus) }}</span><span class="status" :class="chapterDetail.visibility === 0 ? 'approved' : 'rejected'">{{ visibilityLabel(chapterDetail.visibility) }}</span></div></header>
            <div v-if="chapterDetail.hasPendingRevision" class="notice">Đang hiển thị bản hiện tại của chương. Bản sửa đang chờ duyệt chưa được áp dụng. <button class="link-button" @click="openModeration('chapterRevision', chapterDetail.chapterId, chapterDetail.pendingRevisionId)">Xem bản sửa trong Kiểm duyệt nội dung</button></div>
            <div v-else-if="chapterDetail.reviewStatus !== 1" class="notice">Đây là nội dung chưa được xuất bản công khai.</div>
            <div class="chapter-content">{{ chapterDetail.content || 'Chương chưa có nội dung.' }}</div>
          </article>
        </template>

        <template v-else-if="detail">
          <div class="novel-detail"><img :src="cover(detail.coverUrl)" alt="" @error="coverError"/><div><p>{{ detail.description || 'Chưa có mô tả.' }}</p><div class="status-stack"><span class="status" :class="reviewClass(detail.reviewStatus)">{{ reviewLabel(detail.reviewStatus) }}</span><span class="status" :class="detail.visibility === 0 ? 'approved' : 'rejected'">{{ visibilityLabel(detail.visibility) }}</span></div></div></div>
          <div v-if="detail.hasPendingRevision" class="notice">Truyện có bản sửa đang chờ duyệt. <button class="link-button" @click="openModeration('novelRevision', detail.novelId, detail.pendingRevisionId)">Mở kiểm duyệt</button></div>
          <h3>Danh sách chương</h3>
          <div class="chapter-admin-list"><div v-for="chapter in detail.chapters" :key="chapter.chapterId" class="chapter-admin-row"><div class="chapter-summary"><strong>Chương {{ chapter.chapterNumber }}: {{ chapter.title }}</strong><div class="status-stack"><span class="status" :class="reviewClass(chapter.reviewStatus)">{{ reviewLabel(chapter.reviewStatus) }}</span><span class="status" :class="chapter.visibility === 0 ? 'approved' : 'rejected'">{{ visibilityLabel(chapter.visibility) }}</span><span v-if="chapter.hasPendingRevision" class="status pending">Bản sửa chờ duyệt</span></div></div><div class="chapter-actions"><button class="button" @click="openChapter(chapter)">Xem nội dung</button><button v-if="chapter.reviewStatus === 0 || chapter.hasPendingRevision" class="button" @click="openModeration(chapter.hasPendingRevision ? 'chapterRevision' : 'chapter', chapter.chapterId, chapter.pendingRevisionId)">Mở kiểm duyệt</button></div></div><div v-if="!detail.chapters.length" class="empty">Truyện chưa có chương.</div></div>
        </template>
      </section>
    </div>

    <ConfirmDialog v-if="visibilityItem" :title="visibilityItem.visibility === 0 ? 'Ẩn truyện' : 'Hiện lại truyện'" :message="visibilityMessage" :confirm-label="visibilityItem.visibility === 0 ? 'Ẩn truyện' : 'Hiện lại'" :danger="visibilityItem.visibility === 0" :busy="submitting" :error="actionError" @close="closeVisibility" @confirm="submitVisibility" />
  </section>
</template>

<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { administrationApi } from '../api/adminApi'
import { apiMessage } from '../services/apiError'
import { mediaUrl, useCoverFallback } from '../services/mediaUrl'
import AdminPager from '../components/AdminPager.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const router = useRouter()
const items = ref([]), categories = ref([]), page = ref(1), pageSize = 10, total = ref(0), loading = ref(false)
const message = ref(''), messageError = ref(false), menuId = ref(null)
const draft = reactive({ keyword: '', categoryId: '', reviewStatus: '', visibility: '' })
const filters = reactive({ keyword: '', categoryId: '', reviewStatus: '', visibility: '' })
const detailOpen = ref(false), detailNovelId = ref(null), detail = ref(null), detailLoading = ref(false), detailError = ref(''), detailModal = ref(null)
const chapterView = ref(false), selectedChapter = ref(null), chapterDetail = ref(null), chapterLoading = ref(false), chapterError = ref('')
const chapterListScroll = ref(0)
const visibilityItem = ref(null), submitting = ref(false), actionError = ref('')
const visibilityMessage = computed(() => visibilityItem.value?.visibility === 0
  ? `Ẩn truyện “${visibilityItem.value.title}”? Độc giả sẽ không thể mở truyện và các chương của truyện.`
  : `Hiện lại truyện “${visibilityItem.value?.title}”? Chỉ nội dung đã duyệt và không bị ẩn mới có thể đọc.`)

async function load() {
  loading.value = true; message.value = ''
  try {
    const { data } = await administrationApi.novels({ keyword: filters.keyword || undefined, categoryId: filters.categoryId || undefined, reviewStatus: filters.reviewStatus === '' ? undefined : filters.reviewStatus, visibility: filters.visibility === '' ? undefined : filters.visibility, page: page.value, pageSize })
    items.value = data.items || []; total.value = data.totalItems || 0
    if (!items.value.length && page.value > 1) { page.value--; await load() }
  } catch (error) { message.value = apiMessage(error, 'Không tải được danh sách truyện.'); messageError.value = true } finally { loading.value = false }
}
async function loadCategories() { try { categories.value = (await administrationApi.categories({ page: 1, pageSize: 100 })).data.items || [] } catch { categories.value = [] } }
function applyFilters() { Object.assign(filters, draft); page.value = 1; load() }
function changePage(value) { page.value = value; load() }
function toggleMenu(id) { menuId.value = menuId.value === id ? null : id }

async function openDetail(item) {
  if (!item) return
  menuId.value = null; detailNovelId.value = item.novelId; detailOpen.value = true; detail.value = null; chapterView.value = false
  detailLoading.value = true; detailError.value = ''
  try { detail.value = (await administrationApi.novel(item.novelId)).data }
  catch (error) { detailError.value = error.response?.status >= 500 ? 'Không tải được chi tiết truyện' : apiMessage(error, 'Không tải được chi tiết truyện') }
  finally { detailLoading.value = false }
}
async function retryDetail() { const item = items.value.find(x => x.novelId === detailNovelId.value) || (detailNovelId.value ? { novelId: detailNovelId.value } : null); if (item) await openDetail(item) }
function closeDetail() { if (detailLoading.value || chapterLoading.value) return; detailOpen.value = false; chapterView.value = false }

async function openChapter(chapter) {
  chapterListScroll.value = detailModal.value?.scrollTop || 0
  selectedChapter.value = chapter; chapterView.value = true; chapterDetail.value = null; chapterError.value = ''
  await nextTick(); if (detailModal.value) detailModal.value.scrollTop = 0
  await loadChapter()
}
async function loadChapter() {
  if (!detail.value || !selectedChapter.value) return
  chapterLoading.value = true; chapterError.value = ''
  try { chapterDetail.value = (await administrationApi.novelChapter(detail.value.novelId, selectedChapter.value.chapterId)).data }
  catch (error) { chapterError.value = error.response?.status >= 500 ? 'Không tải được nội dung chương.' : apiMessage(error, 'Không tải được nội dung chương.') }
  finally { chapterLoading.value = false }
}
function retryChapter() { loadChapter() }
async function backToChapterList() { chapterView.value = false; chapterDetail.value = null; chapterError.value = ''; await nextTick(); if (detailModal.value) detailModal.value.scrollTop = chapterListScroll.value }

function openVisibility(item) { menuId.value = null; visibilityItem.value = item; actionError.value = '' }
function closeVisibility() { if (!submitting.value) visibilityItem.value = null }
async function submitVisibility() { if (submitting.value) return; submitting.value = true; actionError.value = ''; const item = visibilityItem.value; try { await administrationApi.setNovelVisibility(item.novelId, item.visibility !== 0); visibilityItem.value = null; await load(); message.value = `Đã ${item.visibility === 0 ? 'ẩn' : 'hiện lại'} truyện “${item.title}”.`; messageError.value = false } catch (error) { actionError.value = apiMessage(error, 'Không cập nhật được trạng thái truyện.') } finally { submitting.value = false } }
function openModeration(type, id, pendingRevisionId) { let targetType = type, targetId = id; if (type === 'novelRevision' || type === 'chapterRevision') targetId = pendingRevisionId; detailOpen.value = false; router.push({ path: '/moderation', query: { type: targetType, id: targetId } }) }

const reviewLabel = value => value === 1 ? 'Đã duyệt' : value === 2 ? 'Từ chối' : 'Chờ duyệt'
const reviewClass = value => value === 1 ? 'approved' : value === 2 ? 'rejected' : 'pending'
const visibilityLabel = value => value === 0 ? 'Công khai' : value === 1 ? 'Tác giả ẩn' : 'Admin ẩn'
const formatDate = value => new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value))
const cover = mediaUrl, coverError = useCoverFallback
onMounted(() => { loadCategories(); load() })
</script>

<style scoped>
.novel-modal { max-height: min(88vh, 920px); overflow-y: auto; }
.chapter-admin-row { gap: 1rem; }
.chapter-summary { min-width: 0; flex: 1; }
.chapter-actions { display: flex; flex-wrap: wrap; gap: .5rem; justify-content: flex-end; }
.back-button { margin-bottom: 1rem; }
.chapter-reader { display: grid; gap: 1rem; }
.chapter-reader header { display: grid; gap: .45rem; }
.chapter-reader h3 { margin: 0; font-size: 1.45rem; }
.chapter-kicker { margin: 0; color: var(--muted); font-weight: 700; }
.chapter-content { white-space: pre-wrap; overflow-wrap: anywhere; line-height: 1.8; padding: 1.25rem; border-radius: 14px; background: var(--surface-soft, rgba(127, 127, 127, .08)); color: var(--text); min-height: 12rem; }
.detail-error { padding: 1.5rem 0; }
@media (max-width: 700px) { .chapter-admin-row { align-items: stretch; flex-direction: column; } .chapter-actions { justify-content: flex-start; } .chapter-content { padding: 1rem; } }
</style>
