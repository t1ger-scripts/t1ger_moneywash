<script setup lang="ts">
import { computed } from 'vue'
import { LockKeyhole, ShieldCheck, X } from '@lucide/vue'

const props = defineProps<{ activeTab: string }>()
defineEmits<{ close: [] }>()

const pagePath = computed(() => props.activeTab === 'Marketplace' ? 'marketplace' : 'portfolio')
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
        <span>{{ activeTab }} · Ledger Capital</span>
        <X :size="13" />
      </div>
      <button class="window-close" title="Close" @click="$emit('close')"><X :size="17" /></button>
    </div>

    <div class="address-row">
      <div class="address-bar">
        <LockKeyhole :size="14" />
        <span class="protocol">https://</span><span>ledgercapital.com/{{ pagePath }}</span>
      </div>
      <div class="secure-status"><span class="status-dot" /> SECURE SESSION</div>
    </div>
  </header>
</template>
