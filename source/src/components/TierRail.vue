<script setup lang="ts">
import { Check, LockKeyhole } from '@lucide/vue'
import { toRoman } from '@/lib/format'
import type { BusinessTier } from '@/types/business'

defineProps<{
  tiers: BusinessTier[]
  selectedType: string
  reputation: number
  counts: Record<string, number>
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
    }" @click="$emit('select', tier)">
      <span class="tier-number">{{ toRoman(tier.tier) }}</span>
      <span class="tier-copy">
        <strong>{{ tier.label }}</strong>
        <small>{{ counts[tier.type] ?? 0 }} locations</small>
      </span>
      <span v-if="reputation < tier.requiredPoints" class="tier-state">
        <LockKeyhole :size="13" /> {{ tier.requiredPoints.toLocaleString() }}
      </span>
      <span v-else class="tier-state unlocked">
        <Check :size="13" /> ELIGIBLE
      </span>
    </button>
  </div>
</template>
