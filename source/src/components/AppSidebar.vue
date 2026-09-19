<script setup lang="ts">
import { BriefcaseBusiness, CircleHelp, LayoutGrid, ShieldCheck } from '@lucide/vue'

defineProps<{
  activeView: string
  reputation: number
  reputationLabel: string
  reputationProgress: number
  nextReputationLabel?: string
  characterName: string
  portfolioCount: number
  portfolioWeight: number
  portfolioLimit: number
}>()

const emit = defineEmits<{
  navigate: [view: string]
  'update:reputation': [value: number]
}>()

function updatePreviewScore(event: Event) {
  const input = event.target as HTMLInputElement
  emit('update:reputation', Number(input.value))
}
</script>

<template>
  <aside class="app-sidebar">
    <div class="brand-lockup">
      <div class="brand-mark">
        <ShieldCheck :size="21" />
      </div>
      <div>
        <strong>LEDGER CAPITAL</strong>
        <span>BUSINESS BROKERAGE</span>
      </div>
    </div>

    <nav class="side-nav" aria-label="Primary">
      <button :class="{ active: activeView === 'market' }" @click="$emit('navigate', 'market')">
        <LayoutGrid :size="17" /> Marketplace
      </button>
      <button :class="{ active: activeView === 'portfolio' }" @click="$emit('navigate', 'portfolio')">
        <BriefcaseBusiness :size="17" /> My portfolio
        <span class="nav-count">{{ portfolioCount }}</span>
      </button>
    </nav>

    <div class="side-section">
      <span class="side-label">YOUR ACCOUNT</span>
      <div class="profile-card">
        <div class="profile-copy">
          <strong>{{ characterName }}</strong>
          <small>MEMBERSHIP STATUS</small>
          <span>{{ reputationLabel }}</span>
        </div>
        <span class="online-dot" />
      </div>
      <div class="metric-row">
        <span>Investor Score</span>
        <strong>{{ reputation.toLocaleString() }}</strong>
      </div>
      <div class="progress-track"><span :style="{ width: `${reputationProgress}%` }" /></div>
      <div class="progress-caption">
        <span>{{ nextReputationLabel ? `Progress to ${nextReputationLabel}` : 'Maximum status achieved' }}</span>
        <strong>{{ Math.round(reputationProgress) }}%</strong>
      </div>
      <div class="metric-row portfolio-metric">
        <span>Portfolio Usage</span>
        <strong>{{ portfolioWeight }} / {{ portfolioLimit }}</strong>
      </div>
      <div class="weight-blocks">
        <span v-for="slot in portfolioLimit" :key="slot" :class="{ filled: slot <= portfolioWeight }" />
      </div>
      <div class="sidebar-preview">
        <div class="sidebar-preview-heading">
          <span>TEST INVESTOR SCORE</span>
          <strong>{{ reputation.toLocaleString() }}</strong>
        </div>

        <input :value="reputation" type="range" min="0" max="16000" step="500" aria-label="Test Investor Score"
          @input="updatePreviewScore" />

        <div class="sidebar-preview-scale">
          <span>0</span>
          <span>16,000</span>
        </div>
      </div>
    </div>

    <div class="side-footer">
      <button>
        <CircleHelp :size="16" /> Help Center
      </button>
    </div>
  </aside>
</template>
