<script setup lang="ts">
import { computed } from 'vue'
import {
  LockKeyhole,
  ShieldCheck,
  X,
} from '@lucide/vue'
import { t } from '@/lib/locale'

const props = defineProps<{
  activeTab: string
  activeView: 'market' | 'portfolio'
}>()

defineEmits<{
  close: []
}>()

const pagePath = computed(() =>
  props.activeView === 'market'
    ? t('browser.chrome.path_marketplace')
    : t('browser.chrome.path_portfolio'),
)
</script>

<template>
  <header class="browser-chrome">
    <div class="window-row">
      <div
        class="traffic-lights"
        aria-hidden="true"
      >
        <span class="traffic red" />
        <span class="traffic amber" />
        <span class="traffic green" />
      </div>

      <div class="browser-tab active-browser-tab">
        <ShieldCheck :size="14" />

        <span>
          {{ activeTab }} ·
          {{ t('browser.chrome.tab_suffix') }}
        </span>

        <X :size="13" />
      </div>

      <button
        class="window-close"
        type="button"
        :title="t('browser.chrome.close')"
        :aria-label="t('browser.chrome.close')"
        @click="$emit('close')"
      >
        <X :size="17" />
      </button>
    </div>

    <div class="address-row">
      <div class="address-bar">
        <LockKeyhole :size="14" />

        <span class="protocol">
          {{ t('browser.chrome.protocol') }}
        </span>

        <span>
          {{ t('browser.chrome.domain') }}/{{ pagePath }}
        </span>
      </div>

      <div class="secure-status">
        <span class="status-dot" />

        {{ t('browser.chrome.secure_session') }}
      </div>
    </div>
  </header>
</template>