<script setup lang="ts">
import { AlertTriangle, ArrowRight, BadgeDollarSign, BarChart3, BriefcaseBusiness, LockKeyhole, MapPin, ShieldCheck, X } from '@lucide/vue'
import { money } from '@/lib/format'
import type { LocationView } from '@/types/business'

defineProps<{
  location?: LocationView
  reputation: number
  owned: boolean
  portfolioWeight: number
  portfolioLimit: number
}>()

defineEmits<{ close: []; purchase: [location: LocationView] }>()
</script>

<template>
  <Transition name="detail-slide">
    <aside v-if="location" class="location-detail">
      <button class="detail-close" @click="$emit('close')"><X :size="16" /></button>
      <span class="detail-kicker">SITE {{ String(location.id).padStart(2, '0') }} · TIER {{ location.tier.tier }}</span>
      <h2>{{ location.brand }}</h2>
      <p class="detail-location"><MapPin :size="14" /> {{ location.district }}</p>

      <div class="detail-price">
        <span>Acquisition price</span>
        <strong>{{ money.format(location.effectivePrice) }}</strong>
      </div>

      <div class="detail-stats">
        <div><BarChart3 :size="16" /><span>Expected revenue</span><strong>{{ money.format(location.tier.expectedRevenue) }} / cycle</strong></div>
        <div><BadgeDollarSign :size="16" /><span>Service fee</span><strong>{{ location.tier.launderFee }}%</strong></div>
        <div><BriefcaseBusiness :size="16" /><span>Portfolio usage</span><strong>{{ location.tier.weight }} / {{ portfolioLimit }}</strong></div>
      </div>

      <div v-if="location.locked" class="restriction-box">
        <LockKeyhole :size="16" />
        <div><strong>INVESTOR SCORE REQUIRED</strong><span>{{ (location.tier.requiredPoints - reputation).toLocaleString() }} more points needed</span></div>
      </div>
      <div v-else-if="portfolioWeight + location.tier.weight > portfolioLimit" class="restriction-box">
        <AlertTriangle :size="16" />
        <div><strong>PORTFOLIO LIMIT</strong><span>Free up capacity before acquiring this site.</span></div>
      </div>
      <div v-else class="verified-box"><ShieldCheck :size="16" /> Eligible to purchase</div>

      <button
        class="purchase-button"
        :disabled="location.locked || owned || portfolioWeight + location.tier.weight > portfolioLimit"
        @click="$emit('purchase', location)"
      >
        <template v-if="owned">Already owned</template>
        <template v-else-if="location.locked"><LockKeyhole :size="15" /> Score requirement not met</template>
        <template v-else>Review purchase <ArrowRight :size="16" /></template>
      </button>
      <small class="escrow-note">Funds are held in escrow until the transfer is confirmed.</small>
    </aside>
  </Transition>
</template>
