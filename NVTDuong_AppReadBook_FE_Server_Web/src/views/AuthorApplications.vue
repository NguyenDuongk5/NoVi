<template>
  <section class="page">
    <header class="page-header"><div><h1>Yêu cầu tác giả</h1><p class="subtitle">Duyệt quyền sáng tác cho tài khoản độc giả.</p></div><button class="button" :disabled="loading" @click="load">Tải lại</button></header>
    <div v-if="error" class="notice error" role="alert">{{ error }} <button class="link-button" @click="load">Thử lại</button></div>
    <div class="card">
      <div v-if="loading && !items.length" class="empty">Đang tải yêu cầu…</div>
      <div v-else-if="!items.length" class="empty">Không có yêu cầu tác giả.</div>
      <div v-else class="table-wrap"><table class="data-table">
        <thead><tr><th>Người gửi</th><th>Lời nhắn</th><th>Ngày gửi</th><th>Trạng thái</th><th>Thao tác</th></tr></thead>
        <tbody><tr v-for="item in items" :key="item.applicationId" :data-application-id="item.applicationId">
          <td><strong>{{ item.fullName }}</strong><br><small>{{ item.email }}</small></td><td>{{ item.message || 'Không có lời nhắn' }}</td><td>{{ formatDate(item.createdAt) }}</td><td><span class="status" :class="statusClass(item.status)">{{ statusLabel(item.status) }}</span><div v-if="item.decisionReason"><small>{{ item.decisionReason }}</small></div></td>
          <td><div v-if="item.status === 0" class="actions"><button class="button primary" @click="open(item,true)">Duyệt</button><button class="button danger" @click="open(item,false)">Từ chối</button></div><span v-else>Đã xử lý</span></td>
        </tr></tbody>
      </table></div>
      <AdminPager :page="page" :page-size="pageSize" :total="total" :busy="loading" @change="changePage" />
    </div>
    <DecisionDialog v-if="decision" :approve="decision.approve" :item-title="decision.item.fullName" :busy="submitting" :error="decisionError" @close="closeDecision" @confirm="submitDecision" />
  </section>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import { publishingAdminApi } from '../api/adminApi'; import { apiMessage } from '../services/apiError'
import AdminPager from '../components/AdminPager.vue'; import DecisionDialog from '../components/DecisionDialog.vue'
const items=ref([]),page=ref(1),pageSize=10,total=ref(0),loading=ref(false),error=ref(''),decision=ref(null),submitting=ref(false),decisionError=ref('')
async function load(){ loading.value=true;error.value='';try{const {data}=await publishingAdminApi.authorApplications(page.value,pageSize);items.value=data.items||[];total.value=data.totalItems||0;if(!items.value.length&&page.value>1){page.value--;await load()}}catch(e){error.value=apiMessage(e,'Không tải được yêu cầu tác giả.')}finally{loading.value=false}}
function changePage(value){page.value=value;load()} function open(item,approve){decision.value={item,approve};decisionError.value=''} function closeDecision(){if(!submitting.value)decision.value=null}
async function submitDecision(reason){if(submitting.value)return;submitting.value=true;decisionError.value='';try{await publishingAdminApi.decideAuthorApplication(decision.value.item.applicationId,decision.value.approve,reason||null);decision.value=null;await load()}catch(e){if(e.response?.status===409){decision.value=null;await load();error.value='Yêu cầu đã được quản trị viên khác xử lý. Danh sách đã được cập nhật.'}else decisionError.value=apiMessage(e,'Không xử lý được yêu cầu.')}finally{submitting.value=false}}
const statusLabel=s=>s===0?'Chờ duyệt':s===1?'Đã duyệt':'Từ chối';const statusClass=s=>s===0?'pending':s===1?'approved':'rejected';const formatDate=v=>new Intl.DateTimeFormat('vi-VN',{dateStyle:'short',timeStyle:'short'}).format(new Date(v));onMounted(load)
</script>
