<script setup lang="ts">
import { BriefcaseBusiness, CircleHelp, LayoutGrid, ShieldCheck } from '@lucide/vue'
import { t } from '@/lib/locale'

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
  openHelp: []
}>()

</script>

<template>
  <aside class="app-sidebar">
    <div class="brand-lockup">
      <div class="brand-mark">
        <ShieldCheck :size="21" />
      </div>
      <div>
        <strong>
          {{ t('browser.brand.name') }}
        </strong>

        <span>
          {{ t('browser.brand.subtitle') }}
        </span>
      </div>
    </div>

    <nav class="side-nav" :aria-label="t('browser.navigation.primary_label')">
      <button :class="{ active: activeView === 'market' }" @click="$emit('navigate', 'market')">
        <LayoutGrid :size="17" />
        {{ t('browser.navigation.marketplace') }}
      </button>
      <button :class="{ active: activeView === 'portfolio' }" @click="$emit('navigate', 'portfolio')">
        <BriefcaseBusiness :size="17" />
        {{ t('browser.navigation.portfolio') }}
        <span class="nav-count">{{ portfolioCount }}</span>
      </button>
    </nav>

    <div class="side-section">
      <span class="side-label">
        {{ t('browser.account.heading') }}
      </span>
      <div class="profile-card">
        <div class="profile-copy">
          <strong>{{ characterName }}</strong>
          <small>
            {{ t('browser.account.membership_status') }}
          </small>
          <span>{{ reputationLabel }}</span>
        </div>
        <span class="online-dot" />
      </div>
      <div class="metric-row">
        <span>
          {{ t('browser.account.investor_score') }}
        </span>
        <strong>{{ reputation.toLocaleString() }}</strong>
      </div>
      <div class="progress-track"><span :style="{ width: `${reputationProgress}%` }" /></div>
      <div class="progress-caption">
        <span>
          {{
            nextReputationLabel
              ? t('browser.account.progress_to', {
                level: nextReputationLabel,
              })
              : t('browser.account.maximum_status')
          }}
        </span>
        <strong>{{ Math.round(reputationProgress) }}%</strong>
      </div>
      <div class="metric-row portfolio-metric">
        <span>
          {{ t('browser.account.portfolio_usage') }}
        </span>
        <strong>{{ portfolioWeight }} / {{ portfolioLimit }}</strong>
      </div>
      <div class="weight-blocks">
        <span v-for="slot in portfolioLimit" :key="slot" :class="{ filled: slot <= portfolioWeight }" />
      </div>
    </div>

    <div class="side-footer">
      <button type="button" @click="$emit('openHelp')">
        <CircleHelp :size="16" />
        {{ t('browser.navigation.help_center') }}
      </button>
    </div>
  </aside>
</template>
