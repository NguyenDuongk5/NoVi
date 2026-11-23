<template>
  <div class="pager" v-if="total > 0">
    <button class="button" :disabled="page <= 1 || busy" @click="$emit('change', page - 1)">Trang trước</button>
    <span>Trang {{ page }} / {{ pages }} · {{ total }} mục</span>
    <button class="button" :disabled="page >= pages || busy" @click="$emit('change', page + 1)">Trang sau</button>
  </div>
</template>
<script setup>
import { computed } from 'vue'
const props = defineProps({ page:Number, pageSize:Number, total:Number, busy:Boolean })
defineEmits(['change'])
const pages = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)))
</script>
