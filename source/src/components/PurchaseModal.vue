<script setup lang="ts">
import { computed } from 'vue'
import {
    AlertTriangle,
    Building2,
    MapPin,
    X,
} from '@lucide/vue'
import { money, toRoman } from '@/lib/format'
import type { LocationView } from '@/types/business'

const props = defineProps<{
    location: LocationView
    reputation: number
    balance: number
    portfolioWeight: number
    portfolioLimit: number
    ownsType: boolean
}>()

defineEmits<{
    close: []
    confirm: [location: LocationView]
}>()

const resultingWeight = computed(() => {
    return props.portfolioWeight + props.location.tier.weight
})

const restriction = computed(() => {
    if (props.location.status !== 'available') {
        return 'This listing is no longer available.'
    }

    if (props.reputation < props.location.tier.requiredPoints) {
        return 'Your Investor Score does not meet this tier requirement.'
    }

    if (props.ownsType) {
        return `You already have an active ${props.location.tier.label}.`
    }

    if (props.balance < props.location.effectivePrice) {
        return 'You do not have enough funds to complete this acquisition.'
    }

    if (resultingWeight.value > props.portfolioLimit) {
        return 'This acquisition would exceed your portfolio limit.'
    }

    return undefined
})
</script>

<template>
    <div class="modal-backdrop" @click.self="$emit('close')">
        <section class="purchase-modal" role="dialog" aria-modal="true" aria-label="Confirm business acquisition">
            <button class="modal-close" type="button" aria-label="Close" @click="$emit('close')">
                <X :size="16" />
            </button>

            <div class="purchase-modal-heading">
                <div class="purchase-modal-icon">
                    <Building2 :size="21" />
                </div>

                <div>
                    <span class="modal-kicker">FINAL REVIEW</span>
                    <h2>Confirm acquisition</h2>
                </div>
            </div>

            <div class="purchase-target">
                <strong>{{ location.brand }}</strong>

                <span>
                    {{ location.tier.label }}
                    · Tier {{ toRoman(location.tier.tier) }}
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
                    <span>ACQUISITION PRICE</span>
                    <strong>{{ money.format(location.effectivePrice) }}</strong>
                </div>

                <div>
                    <span>BUSINESS TYPE</span>
                    <strong>{{ location.tier.label }}</strong>
                </div>

                <div>
                    <span>PORTFOLIO WEIGHT</span>
                    <strong>{{ location.tier.weight }}</strong>
                </div>

                <div>
                    <span>CURRENT USAGE</span>
                    <strong>{{ portfolioWeight }} / {{ portfolioLimit }}</strong>
                </div>

                <div>
                    <span>RESULTING USAGE</span>
                    <strong :class="{
                        exceeded: resultingWeight > portfolioLimit,
                    }">
                        {{ resultingWeight }} / {{ portfolioLimit }}
                    </strong>
                </div>
            </div>

            <div v-if="restriction" class="purchase-restriction">
                <AlertTriangle :size="16" />
                <span>{{ restriction }}</span>
            </div>

            <p class="purchase-confirmation-note">
                The acquisition price will be charged immediately after confirmation.
            </p>

            <div class="modal-footer-actions">
                <button class="portfolio-secondary" type="button" @click="$emit('close')">
                    Cancel
                </button>

                <button class="portfolio-primary" type="button" :disabled="!!restriction"
                    @click="$emit('confirm', location)">
                    Confirm Acquisition
                </button>
            </div>
        </section>
    </div>
</template>