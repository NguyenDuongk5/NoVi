<template><div class="modal-backdrop" @click.self="close"><section class="modal compact" role="dialog" aria-modal="true" tabindex="-1" @keydown.esc="close"><h2>{{ title }}</h2><p>{{ message }}</p><div v-if="error" class="notice error" role="alert">{{ error }}</div><div class="actions modal-actions"><button class="button" :disabled="busy" @click="close">Hủy</button><button ref="confirmButton" class="button" :class="danger?'danger':'primary'" :disabled="busy" @click="$emit('confirm')">{{ busy?'Đang xử lý…':confirmLabel }}</button></div></section></div></template>
<script setup>
import{nextTick,onBeforeUnmount,onMounted,ref}from'vue'
const props=defineProps({title:String,message:String,confirmLabel:String,danger:Boolean,busy:Boolean,error:String}),emit=defineEmits(['close','confirm']),confirmButton=ref(null);let opener
function close(){if(!props.busy)emit('close')}
onMounted(()=>{opener=document.activeElement;nextTick(()=>confirmButton.value?.focus())});onBeforeUnmount(()=>opener?.focus?.())
</script>
