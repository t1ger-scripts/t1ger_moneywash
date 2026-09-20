<script setup lang="ts">
import { Check, LockKeyhole } from '@lucide/vue'
import { t } from '@/lib/locale'
import type { BusinessTier } from '@/types/business'

defineProps<{
  tiers: BusinessTier[]
  selectedType: string
  reputation: number
}>()

defineEmits<{ select: [tier: BusinessTier] }>()
</script>

<template>
  <div class="tier-rail">
    <button v-for="(tier, index) in tiers" :key="tier.type" class="tier-pill" :class="{
      selected: selectedType === tier.type,
      locked: reputation < tier.requiredPoints,
      'eligibility-boundary':
        reputation < tier.requiredPoints &&
        reputation >= (tiers[index - 1]?.requiredPoints ?? 0),
    }" :disabled="reputation < tier.requiredPoints" @click="$emit('select', tier)">
      <span class="tier-copy">
        <strong>{{ tier.label }}</strong>
      </span>
      <span v-if="reputation < tier.requiredPoints" class="tier-state">
        <LockKeyhole :size="13" /> {{ tier.requiredPoints.toLocaleString() }}
      </span>
      <span v-else class="tier-state unlocked">
        <Check :size="13" /> {{ t('browser.tiers.eligible') }}
      </span>
    </button>
  </div>
</template>
