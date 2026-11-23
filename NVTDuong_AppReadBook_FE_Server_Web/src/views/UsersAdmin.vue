<template>
  <section class="page">
    <header class="page-header"><div><h1>Người dùng</h1><p class="subtitle">Tìm kiếm và quản lý trạng thái tài khoản NoVi.</p></div><button class="button" :disabled="loading" @click="load">Tải lại</button></header>
    <form class="filters" @submit.prevent="applyFilters">
      <label>Tìm kiếm<input v-model="draft.keyword" placeholder="Tên hoặc email" /></label>
      <label>Vai trò<select v-model="draft.role"><option value="">Tất cả</option><option value="0">Độc giả</option><option value="1">Tác giả/Dịch giả</option><option value="2">Quản trị viên</option></select></label>
      <label>Trạng thái<select v-model="draft.status"><option value="">Tất cả</option><option value="1">Đang hoạt động</option><option value="0">Đã khóa</option></select></label>
      <button class="button primary" :disabled="loading">Lọc</button>
    </form>
    <div v-if="message" class="notice" :class="{error:messageError}" role="status">{{ message }} <button v-if="messageError" class="link-button" @click="load">Thử lại</button></div>
    <div class="card">
      <div v-if="loading && !items.length" class="empty">Đang tải người dùng…</div>
      <div v-else-if="!items.length" class="empty">Không tìm thấy người dùng phù hợp.</div>
      <div v-else class="table-wrap"><table class="data-table"><thead><tr><th>Người dùng</th><th>Email</th><th>Vai trò</th><th>Trạng thái</th><th>Thao tác</th></tr></thead>
        <tbody><tr v-for="item in items" :key="item.userId" :data-user-id="item.userId">
          <td><strong>{{ item.displayName || item.fullName }}</strong><br><small>{{ item.fullName }}</small></td><td>{{ item.email }}</td><td>{{ roleLabel(item.role) }}</td>
          <td><span class="status" :class="item.status===1?'approved':'rejected'">{{ item.status===1?'Đang hoạt động':'Đã khóa' }}</span></td>
          <td><button class="button" :class="item.status===1?'danger':'primary'" :disabled="item.role===2" :title="item.role===2?'Không thay đổi trạng thái quản trị viên':''" @click="openStatus(item)">{{ item.status===1?'Khóa':'Mở khóa' }}</button></td>
        </tr></tbody></table></div>
      <AdminPager :page="page" :page-size="pageSize" :total="total" :busy="loading" @change="changePage" />
    </div>
    <ConfirmDialog v-if="selected" :title="selected.status===1?'Khóa tài khoản':'Mở khóa tài khoản'" :message="confirmMessage" :confirm-label="selected.status===1?'Khóa':'Mở khóa'" :danger="selected.status===1" :busy="submitting" :error="actionError" @close="closeStatus" @confirm="submitStatus" />
  </section>
</template>
<script setup>
import { computed, reactive, ref, onMounted } from 'vue'
import { administrationApi } from '../api/adminApi'; import { apiMessage } from '../services/apiError'
import AdminPager from '../components/AdminPager.vue'; import ConfirmDialog from '../components/ConfirmDialog.vue'
const items=ref([]),page=ref(1),pageSize=10,total=ref(0),loading=ref(false),message=ref(''),messageError=ref(false),selected=ref(null),submitting=ref(false),actionError=ref('')
const draft=reactive({keyword:'',role:'',status:''}),filters=reactive({keyword:'',role:'',status:''})
const confirmMessage=computed(()=>`${selected.value?.status===1?'Khóa':'Mở khóa'} tài khoản ${selected.value?.displayName||selected.value?.fullName} (${selected.value?.email})?`)
async function load(){loading.value=true;message.value='';try{const {data}=await administrationApi.users({keyword:filters.keyword||undefined,role:filters.role===''?undefined:filters.role,status:filters.status===''?undefined:filters.status,page:page.value,pageSize});items.value=data.items||[];total.value=data.totalItems||0;if(!items.value.length&&page.value>1){page.value--;await load()}}catch(e){message.value=apiMessage(e,'Không tải được người dùng.');messageError.value=true}finally{loading.value=false}}
function applyFilters(){Object.assign(filters,draft);page.value=1;load()} function changePage(v){page.value=v;load()} function openStatus(item){selected.value=item;actionError.value=''} function closeStatus(){if(!submitting.value)selected.value=null}
async function submitStatus(){if(submitting.value)return;submitting.value=true;actionError.value='';const item=selected.value;try{await administrationApi.setUserStatus(item.userId,item.status!==1);selected.value=null;await load();message.value=`Đã ${item.status===1?'khóa':'mở khóa'} tài khoản ${item.email}.`;messageError.value=false}catch(e){actionError.value=apiMessage(e,'Không cập nhật được trạng thái tài khoản.')}finally{submitting.value=false}}
const roleLabel=r=>r===2?'Quản trị viên':r===1?'Tác giả/Dịch giả':'Độc giả';onMounted(load)
</script>
