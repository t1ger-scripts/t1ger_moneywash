<script setup lang="ts">
import {
  AlertTriangle,
  ArrowRight,
  BadgeDollarSign,
  BarChart3,
  BriefcaseBusiness,
  LockKeyhole,
  MapPin,
  ShieldCheck,
  X,
} from '@lucide/vue'
import { money, toRoman } from '@/lib/format'
import { t } from '@/lib/locale'
import type { LocationView } from '@/types/business'

defineProps<{
  location?: LocationView
  reputation: number
  balance: number
  ownsType: boolean
  portfolioWeight: number
  portfolioLimit: number
}>()

defineEmits<{
  close: []
  purchase: [location: LocationView]
}>()
</script>

<template>
  <Transition name="detail-slide">
    <aside v-if="location" class="location-detail">
      <button
        class="detail-close"
        type="button"
        :aria-label="t('browser.listing_detail.close_label')"
        @click="$emit('close')"
      >
        <X :size="16" />
      </button>

      <span class="detail-kicker">
        {{
          t('browser.listing_detail.kicker', {
            id: String(location.id).padStart(2, '0'),
            tier: toRoman(location.tier.tier),
          })
        }}
      </span>

      <h2>{{ location.brand }}</h2>

      <p class="detail-location">
        <MapPin :size="14" />

        <span>
          {{ location.street ?? location.zone }}

          <template v-if="location.crossingStreet">
            / {{ location.crossingStreet }}
          </template>

          <template v-if="location.street && location.zone">
            · {{ location.zone }}
          </template>
        </span>
      </p>

      <div class="detail-price">
        <span>{{ t('browser.listing_detail.acquisition_price') }}</span>
        <strong>{{ money.format(location.effectivePrice) }}</strong>
      </div>

      <div class="detail-stats">
        <div>
          <BarChart3 :size="16" />
          <span>{{ t('browser.listing_detail.expected_revenue') }}</span>
          <strong>
            {{
              t('browser.listing_detail.per_cycle', {
                amount: money.format(location.tier.expectedRevenue),
              })
            }}
          </strong>
        </div>

        <div>
          <BadgeDollarSign :size="16" />
          <span>{{ t('browser.listing_detail.service_fee') }}</span>
          <strong>{{ location.tier.launderFee }}%</strong>
        </div>

        <div>
          <BriefcaseBusiness :size="16" />
          <span>{{ t('browser.listing_detail.portfolio_weight') }}</span>
          <strong>{{ location.tier.weight }}</strong>
        </div>
      </div>

      <div v-if="location.status !== 'available'" class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>{{ t('browser.listing_detail.unavailable_title') }}</strong>
          <span>{{ t('browser.listing_detail.unavailable_description') }}</span>
        </div>
      </div>

      <div v-else-if="location.locked" class="restriction-box">
        <LockKeyhole :size="16" />

        <div>
          <strong>{{ t('browser.listing_detail.score_required_title') }}</strong>
          <span>
            {{
              t('browser.listing_detail.points_needed', {
                points: (
                  location.tier.requiredPoints - reputation
                ).toLocaleString(),
              })
            }}
          </span>
        </div>
      </div>

      <div v-else-if="ownsType" class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>{{ t('browser.listing_detail.type_active_title') }}</strong>
          <span>
            {{
              t('browser.listing_detail.type_active_description', {
                type: location.tier.label,
              })
            }}
          </span>
        </div>
      </div>

      <div v-else-if="balance < location.effectivePrice" class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>{{ t('browser.listing_detail.insufficient_funds_title') }}</strong>
          <span>
            {{ t('browser.listing_detail.insufficient_funds_description') }}
          </span>
        </div>
      </div>

      <div
        v-else-if="portfolioWeight + location.tier.weight > portfolioLimit"
        class="restriction-box"
      >
        <AlertTriangle :size="16" />

        <div>
          <strong>{{ t('browser.listing_detail.portfolio_limit_title') }}</strong>
          <span>
            {{ t('browser.listing_detail.portfolio_limit_description') }}
          </span>
        </div>
      </div>

      <div v-else class="verified-box">
        <ShieldCheck :size="16" />
        {{ t('browser.listing_detail.eligible') }}
      </div>

      <button
        class="purchase-button"
        type="button"
        :disabled="
          location.status !== 'available' ||
          location.locked ||
          ownsType ||
          balance < location.effectivePrice ||
          portfolioWeight + location.tier.weight > portfolioLimit
        "
        @click="$emit('purchase', location)"
      >
        <template v-if="location.status !== 'available'">
          {{ t('browser.listing_detail.button_unavailable') }}
        </template>

        <template v-else-if="location.locked">
          <LockKeyhole :size="15" />
          {{ t('browser.listing_detail.button_score_required') }}
        </template>

        <template v-else-if="ownsType">
          {{ t('browser.listing_detail.button_type_active') }}
        </template>

        <template v-else-if="balance < location.effectivePrice">
          {{ t('browser.listing_detail.button_insufficient_funds') }}
        </template>

        <template v-else-if="portfolioWeight + location.tier.weight > portfolioLimit">
          {{ t('browser.listing_detail.button_portfolio_limit') }}
        </template>

        <template v-else>
          {{ t('browser.listing_detail.button_review') }}
          <ArrowRight :size="16" />
        </template>
      </button>

      <small class="escrow-note">
        {{ t('browser.listing_detail.review_note') }}
      </small>
    </aside>
  </Transition>
</template>
