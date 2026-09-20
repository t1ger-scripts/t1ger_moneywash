<script setup lang="ts">
import { computed } from 'vue'
import {
  AlertTriangle,
  Building2,
  MapPin,
  X,
} from '@lucide/vue'
import { money, toRoman } from '@/lib/format'
import { t } from '@/lib/locale'
import type { LocationView } from '@/types/business'

const props = defineProps<{
  location: LocationView
  reputation: number
  balance: number
  portfolioWeight: number
  portfolioLimit: number
  ownsType: boolean
  processing: boolean
}>()

const emit = defineEmits<{
  close: []
  confirm: [location: LocationView]
}>()

const resultingWeight = computed(() => {
  return props.portfolioWeight + props.location.tier.weight
})

const restriction = computed(() => {
  if (props.location.status !== 'available') {
    return t('browser.purchase.restriction_unavailable')
  }

  if (props.reputation < props.location.tier.requiredPoints) {
    return t('browser.purchase.restriction_score')
  }

  if (props.ownsType) {
    return t('browser.purchase.restriction_type', {
      type: props.location.tier.label,
    })
  }

  if (props.balance < props.location.effectivePrice) {
    return t('browser.purchase.restriction_funds')
  }

  if (resultingWeight.value > props.portfolioLimit) {
    return t('browser.purchase.restriction_portfolio')
  }

  return undefined
})
</script>

<template>
  <div class="modal-backdrop" @click.self="!processing && emit('close')">
    <section
      class="purchase-modal"
      role="dialog"
      aria-modal="true"
      :aria-label="t('browser.purchase.dialog_label')"
    >
      <button
        class="modal-close"
        :class="{ processing }"
        :disabled="processing"
        :aria-label="t('browser.purchase.close_label')"
        @click="emit('close')"
      >
        <X :size="16" />
      </button>

      <div class="purchase-modal-heading">
        <div class="purchase-modal-icon">
          <Building2 :size="21" />
        </div>

        <div>
          <span class="modal-kicker">
            {{ t('browser.purchase.final_review') }}
          </span>

          <h2>{{ t('browser.purchase.confirm_title') }}</h2>
        </div>
      </div>

      <div class="purchase-target">
        <strong>{{ location.brand }}</strong>

        <span>
          {{ location.tier.label }}
          ·
          {{
            t('browser.purchase.tier', {
              tier: toRoman(location.tier.tier),
            })
          }}
        </span>

        <small>
          <MapPin :size="12" />

          <span>
            {{ location.street ?? location.zone }}

            <template v-if="location.crossingStreet">
              / {{ location.crossingStreet }}
            </template>

            <template v-if="location.street && location.zone">
              · {{ location.zone }}
            </template>
          </span>
        </small>
      </div>

      <div class="purchase-summary">
        <div class="purchase-summary-price">
          <span>{{ t('browser.purchase.acquisition_price') }}</span>
          <strong>{{ money.format(location.effectivePrice) }}</strong>
        </div>

        <div>
          <span>{{ t('browser.purchase.business_type') }}</span>
          <strong>{{ location.tier.label }}</strong>
        </div>

        <div>
          <span>{{ t('browser.purchase.portfolio_weight') }}</span>
          <strong>{{ location.tier.weight }}</strong>
        </div>

        <div>
          <span>{{ t('browser.purchase.current_usage') }}</span>
          <strong>{{ portfolioWeight }} / {{ portfolioLimit }}</strong>
        </div>

        <div>
          <span>{{ t('browser.purchase.resulting_usage') }}</span>
          <strong
            :class="{
              exceeded: resultingWeight > portfolioLimit,
            }"
          >
            {{ resultingWeight }} / {{ portfolioLimit }}
          </strong>
        </div>
      </div>

      <div v-if="restriction" class="purchase-restriction">
        <AlertTriangle :size="16" />
        <span>{{ restriction }}</span>
      </div>

      <p class="purchase-confirmation-note">
        {{ t('browser.purchase.confirmation_note') }}
      </p>

      <div class="modal-footer-actions">
        <button
          type="button"
          class="portfolio-secondary"
          :disabled="processing"
          @click="emit('close')"
        >
          {{ t('browser.purchase.cancel') }}
        </button>

        <button
          type="button"
          class="portfolio-primary"
          :disabled="Boolean(restriction) || processing"
          @click="emit('confirm', location)"
        >
          <span v-if="processing" class="action-button-spinner" />

          {{
            processing
              ? t('browser.purchase.processing')
              : t('browser.purchase.confirm')
          }}
        </button>
      </div>
    </section>
  </div>
</template>
