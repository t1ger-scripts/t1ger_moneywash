<script setup lang="ts">
import { computed } from 'vue'
import { BriefcaseBusiness, CircleHelp, LayoutGrid, ShieldCheck } from '@lucide/vue'

const props = defineProps<{
  activeView: string
  reputation: number
  reputationLabel: string
  alias: string
  portfolioCount: number
  portfolioWeight: number
  portfolioLimit: number
}>()

defineEmits<{ navigate: [view: string] }>()

const repProgress = computed(() => Math.min(100, (props.reputation / 15000) * 100))
</script>

<template>
  <aside class="app-sidebar">
    <div class="brand-lockup">
      <div class="brand-mark"><ShieldCheck :size="21" /></div>
      <div>
        <strong>BLACK LEDGER</strong>
        <span>PRIVATE EXCHANGE</span>
      </div>
    </div>

    <nav class="side-nav" aria-label="Primary">
      <button :class="{ active: activeView === 'market' }" @click="$emit('navigate', 'market')">
        <LayoutGrid :size="17" /> Front Exchange
      </button>
      <button :class="{ active: activeView === 'portfolio' }" @click="$emit('navigate', 'portfolio')">
        <BriefcaseBusiness :size="17" /> My portfolio
        <span class="nav-count">{{ portfolioCount }}</span>
      </button>
    </nav>

    <div class="side-section">
      <span class="side-label">YOUR PROFILE</span>
      <div class="profile-card">
        <div class="profile-copy">
          <strong>{{ alias }}</strong>
          <span>{{ reputationLabel }}</span>
        </div>
        <span class="online-dot" />
      </div>
      <div class="metric-row">
        <span>Reputation</span>
        <strong>{{ reputation.toLocaleString() }} RP</strong>
      </div>
      <div class="progress-track"><span :style="{ width: `${repProgress}%` }" /></div>
      <div class="metric-row portfolio-metric">
        <span>Portfolio load</span>
        <strong>{{ portfolioWeight }} / {{ portfolioLimit }}</strong>
      </div>
      <div class="weight-blocks">
        <span v-for="slot in portfolioLimit" :key="slot" :class="{ filled: slot <= portfolioWeight }" />
      </div>
    </div>

    <div class="side-footer">
      <button><CircleHelp :size="16" /> Operations guide</button>
    </div>
  </aside>
</template>
