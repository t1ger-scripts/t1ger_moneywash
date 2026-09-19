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
      <button class="detail-close" type="button" aria-label="Close listing details" @click="$emit('close')">
        <X :size="16" />
      </button>

      <span class="detail-kicker">
        LISTING {{ String(location.id).padStart(2, '0') }}
        · TIER {{ toRoman(location.tier.tier) }}
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
        <span>Acquisition price</span>
        <strong>{{ money.format(location.effectivePrice) }}</strong>
      </div>

      <div class="detail-stats">
        <div>
          <BarChart3 :size="16" />
          <span>Expected revenue</span>
          <strong>
            {{ money.format(location.tier.expectedRevenue) }} / cycle
          </strong>
        </div>

        <div>
          <BadgeDollarSign :size="16" />
          <span>Service fee</span>
          <strong>{{ location.tier.launderFee }}%</strong>
        </div>

        <div>
          <BriefcaseBusiness :size="16" />
          <span>Portfolio weight</span>
          <strong>{{ location.tier.weight }}</strong>
        </div>
      </div>

      <div v-if="location.status !== 'available'" class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>LISTING UNAVAILABLE</strong>
          <span>This location has already been acquired.</span>
        </div>
      </div>

      <div v-else-if="location.locked" class="restriction-box">
        <LockKeyhole :size="16" />

        <div>
          <strong>INVESTOR SCORE REQUIRED</strong>
          <span>
            {{
              (
                location.tier.requiredPoints - reputation
              ).toLocaleString()
            }}
            more points needed
          </span>
        </div>
      </div>

      <div v-else-if="ownsType" class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>TYPE ALREADY ACTIVE</strong>
          <span>
            You may only register one {{ location.tier.label }}.
          </span>
        </div>
      </div>

      <div v-else-if="balance < location.effectivePrice" class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>INSUFFICIENT FUNDS</strong>
          <span>
            Additional funds are required for this acquisition.
          </span>
        </div>
      </div>

      <div v-else-if="
        portfolioWeight + location.tier.weight >
        portfolioLimit
      " class="restriction-box">
        <AlertTriangle :size="16" />

        <div>
          <strong>PORTFOLIO LIMIT</strong>
          <span>
            Free up capacity before acquiring this listing.
          </span>
        </div>
      </div>

      <div v-else class="verified-box">
        <ShieldCheck :size="16" />
        Eligible to acquire
      </div>

      <button class="purchase-button" type="button" :disabled="location.status !== 'available' ||
        location.locked ||
        ownsType ||
        balance < location.effectivePrice ||
        portfolioWeight + location.tier.weight >
        portfolioLimit
        " @click="$emit('purchase', location)">
        <template v-if="location.status !== 'available'">
          Listing unavailable
        </template>

        <template v-else-if="location.locked">
          <LockKeyhole :size="15" />
          Score requirement not met
        </template>

        <template v-else-if="ownsType">
          Type already registered
        </template>

        <template v-else-if="balance < location.effectivePrice">
          Insufficient funds
        </template>

        <template v-else-if="
          portfolioWeight + location.tier.weight >
          portfolioLimit
        ">
          Portfolio limit exceeded
        </template>

        <template v-else>
          Review acquisition
          <ArrowRight :size="16" />
        </template>
      </button>

      <small class="escrow-note">
        Review all acquisition details before confirming.
      </small>
    </aside>
  </Transition>
</template>