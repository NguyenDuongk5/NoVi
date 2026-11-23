<template>
  <section class="page">
    <header class="page-header"><div><h1>Kiểm duyệt nội dung</h1><p class="subtitle">Truyện, chương và bản chỉnh sửa đang chờ duyệt.</p></div><button class="button" :disabled="loading" @click="load">Tải lại</button></header>
    <div v-if="message" class="notice" :class="{error: messageIsError}" role="status">{{ message }} <button v-if="messageIsError" class="link-button" @click="load">Thử lại</button></div>
    <div class="card">
      <div v-if="loading && !items.length" class="empty">Đang tải hàng chờ…</div>
      <div v-else-if="!items.length" class="empty">Hàng chờ kiểm duyệt đang trống.</div>
      <div v-else class="table-wrap"><table class="data-table">
        <thead><tr><th>Loại</th><th>Tiêu đề</th><th>Người gửi</th><th>Ngày gửi</th><th>Thao tác</th></tr></thead>
        <tbody><tr v-for="item in items" :key="`${item.targetType}-${item.id}`" :data-moderation-id="item.id">
          <td><span class="status pending">{{ typeLabel(item.targetType) }}</span></td><td><strong>{{ item.title }}</strong></td><td><code>{{ item.submittedBy }}</code></td><td>{{ formatDate(item.submittedAt) }}</td>
          <td><button class="button primary" @click="showDetail(item)">Xem nội dung</button></td>
        </tr></tbody>
      </table></div>
      <AdminPager :page="page" :page-size="pageSize" :total="total" :busy="loading" @change="changePage" />
    </div>

    <div v-if="selected" class="modal-backdrop" @click.self="closeDetail"><section class="modal wide" role="dialog" aria-modal="true" aria-labelledby="moderation-title">
      <div v-if="detailLoading" class="empty">Đang tải nội dung gửi duyệt…</div>
      <template v-else-if="detail">
        <h2 id="moderation-title">{{ detail.title }}</h2>
        <dl class="detail-grid">
          <dt>Loại</dt><dd>{{ typeLabel(detail.targetType) }}</dd><dt>Người gửi</dt><dd>{{ detail.submitterName }}</dd><dt>Thời điểm</dt><dd>{{ formatDate(detail.submittedAt) }}</dd>
          <template v-if="detail.novelTitle"><dt>Truyện</dt><dd>{{ detail.novelTitle }}</dd></template><template v-if="detail.originalAuthor"><dt>Tác giả gốc</dt><dd>{{ detail.originalAuthor }}</dd></template><template v-if="detail.categoryNames"><dt>Thể loại</dt><dd>{{ detail.categoryNames }}</dd></template>
          <template v-if="detail.description"><dt>Mô tả gửi duyệt</dt><dd>{{ detail.description }}</dd></template><template v-if="detail.chapterNumber != null"><dt>Số chương</dt><dd>{{ detail.chapterNumber }}</dd></template>
        </dl>
        <div v-if="detail.content" class="content-preview">{{ detail.content }}</div>
        <div class="actions" style="margin-top:18px"><button class="button" @click="closeDetail">Đóng</button><button class="button primary" @click="openDecision(true)">Duyệt</button><button class="button danger" @click="openDecision(false)">Từ chối</button></div>
      </template>
      <template v-else><div class="notice error">{{ detailError }}</div><button class="button" @click="closeDetail">Đóng</button></template>
    </section></div>
    <DecisionDialog v-if="decision" :approve="decision.approve" :item-title="detail?.title || selected.title" :busy="submitting" :error="decisionError" @close="closeDecision" @confirm="submitDecision" />
  </section>
</template>
<script setup>
import { onMounted, ref } from 'vue';import { useRoute } from 'vue-router';import { publishingAdminApi } from '../api/adminApi';import { apiMessage } from '../services/apiError';import AdminPager from '../components/AdminPager.vue';import DecisionDialog from '../components/DecisionDialog.vue'
const route=useRoute(),items=ref([]),page=ref(1),pageSize=10,total=ref(0),loading=ref(false),message=ref(''),messageIsError=ref(false),selected=ref(null),detail=ref(null),detailLoading=ref(false),detailError=ref(''),decision=ref(null),submitting=ref(false),decisionError=ref('')
async function load(){loading.value=true;message.value='';try{const{data}=await publishingAdminApi.moderationQueue(page.value,pageSize);items.value=data.items||[];total.value=data.totalItems||0;if(!items.value.length&&page.value>1){page.value--;await load()}}catch(e){message.value=apiMessage(e,'Không tải được hàng chờ.');messageIsError.value=true}finally{loading.value=false}}
function changePage(v){page.value=v;load()} async function showDetail(item){selected.value=item;detail.value=null;detailError.value='';detailLoading.value=true;try{detail.value=(await publishingAdminApi.moderationDetail(item.targetType,item.id)).data}catch(e){detailError.value=apiMessage(e,'Không tải được nội dung gửi duyệt.')}finally{detailLoading.value=false}}
function closeDetail(){if(!submitting.value){selected.value=null;detail.value=null}} function openDecision(approve){decision.value={approve};decisionError.value=''} function closeDecision(){if(!submitting.value)decision.value=null}
async function submitDecision(reason){if(submitting.value)return;submitting.value=true;decisionError.value='';try{await publishingAdminApi.decideModeration(selected.value.targetType,selected.value.id,decision.value.approve,reason||null);decision.value=null;selected.value=null;detail.value=null;await load();message.value='Đã xử lý nội dung và cập nhật hàng chờ.';messageIsError.value=false}catch(e){if(e.response?.status===409){decision.value=null;selected.value=null;detail.value=null;await load();message.value='Nội dung đã được quản trị viên khác xử lý. Danh sách đã được cập nhật.';messageIsError.value=false}else decisionError.value=apiMessage(e,'Không xử lý được nội dung.')}finally{submitting.value=false}}
const labels={novel:'Truyện mới',chapter:'Chương mới',novelRevision:'Bản sửa truyện',chapterRevision:'Bản sửa chương','novel-revision':'Bản sửa truyện','chapter-revision':'Bản sửa chương'};const typeLabel=t=>labels[t]||t;const formatDate=v=>new Intl.DateTimeFormat('vi-VN',{dateStyle:'short',timeStyle:'short'}).format(new Date(v));onMounted(async()=>{await load();if(route.query.type&&route.query.id)await showDetail({targetType:String(route.query.type),id:String(route.query.id),title:'Nội dung gửi duyệt'})})
</script>
