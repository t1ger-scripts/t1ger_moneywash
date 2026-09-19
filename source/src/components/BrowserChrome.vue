<script setup lang="ts">
import { LockKeyhole, ShieldCheck, X } from '@lucide/vue'

defineProps<{ activeTab: string }>()
defineEmits<{ close: [] }>()
</script>

<template>
  <header class="browser-chrome">
    <div class="window-row">
      <div class="traffic-lights" aria-hidden="true">
        <span class="traffic red" />
        <span class="traffic amber" />
        <span class="traffic green" />
      </div>
      <div class="browser-tab active-browser-tab">
        <ShieldCheck :size="14" />
        <span>{{ activeTab }} · Black Ledger</span>
        <X :size="13" />
      </div>
      <button class="window-close" title="Close" @click="$emit('close')"><X :size="17" /></button>
    </div>

    <div class="address-row">
      <div class="address-bar">
        <LockKeyhole :size="14" />
        <span class="protocol">ledger://</span><span>front-exchange/network</span>
      </div>
      <div class="secure-status"><span class="status-dot" /> RELAY SECURE</div>
    </div>
  </header>
</template>
