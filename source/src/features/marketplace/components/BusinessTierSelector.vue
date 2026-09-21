<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

import type { BusinessTier } from '@/domain/marketplace'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { formatNumber } from '@/utils/formatters'

const marketplaceStore = useMarketplaceStore()
const { locale, t } = useI18n()

const tiers = computed(() => marketplaceStore.tiers)

function isTierAccessible(tier: BusinessTier): boolean {
    if (tier.isUnlocked) return true

    return marketplaceStore.locations.some(
        (location) =>
            location.businessType === tier.businessType
            && location.ownership === 'ownedByPlayer',
    )
}

function isTierSelected(tier: BusinessTier): boolean {
    return marketplaceStore.selectedTierNumber === tier.tierNumber
}

function selectTier(tier: BusinessTier): void {
    if (!isTierAccessible(tier)) return

    marketplaceStore.selectTier(tier.tierNumber)
}

function createTierLabel(tier: BusinessTier): string {
    const status = isTierAccessible(tier)
        ? t('portal.tierSelector.available')
        : t('portal.tierSelector.locked')

    return [
        tier.displayName,
        t('portal.tierSelector.tier', {
            number: tier.tierNumber,
        }),
        t('portal.tierSelector.requiredScore', {
            score: formatNumber(
                tier.requiredInvestorScore,
                locale.value,
            ),
        }),
        status,
    ].join(', ')
}
</script>

<template>
    <nav class="tier-selector" :aria-label="t('portal.tierSelector.ariaLabel')">
        <div class="tier-selector__track">
            <button v-for="tier in tiers" :key="tier.businessType" class="tier-selector__item" :class="{
                'tier-selector__item--selected': isTierSelected(tier),
                'tier-selector__item--locked': !isTierAccessible(tier),
            }" type="button" :disabled="!isTierAccessible(tier)" :aria-pressed="isTierSelected(tier)"
                :aria-label="createTierLabel(tier)" @click="selectTier(tier)">
                <span class="tier-selector__number">
                    {{
                        t('portal.tierSelector.tier', {
                            number: tier.tierNumber,
                        })
                    }}
                </span>

                <strong class="tier-selector__name">
                    {{ tier.displayName }}
                </strong>

                <span class="tier-selector__requirement">
                    {{
                        t('portal.tierSelector.scoreRequirement', {
                            score: formatNumber(
                                tier.requiredInvestorScore,
                                locale,
                            ),
                    })
                    }}
                </span>
            </button>
        </div>
    </nav>
</template>

<style scoped lang="scss">
.tier-selector {
    min-width: 0;
    padding: var(--space-4) var(--space-6);
    border-bottom: var(--border-width) solid var(--color-border);
    background: var(--color-background);

    &__track {
        display: grid;
        overflow-x: auto;
        grid-template-columns: repeat(9, minmax(8.5rem, 1fr));
        gap: var(--space-2);
        padding-bottom: var(--space-1);
        scrollbar-width: thin;
        scrollbar-color:
            var(--color-border-strong) transparent;
    }

    &__item {
        display: grid;
        min-height: 5.25rem;
        align-content: center;
        gap: var(--space-1);
        padding: var(--space-3) var(--space-4);
        border: var(--border-width) solid var(--color-border);
        border-radius: var(--radius-md);
        background: var(--color-surface);
        color: var(--color-text-secondary);
        cursor: pointer;
        text-align: left;
        transition:
            border-color var(--duration-fast) var(--ease-standard),
            background-color var(--duration-fast) var(--ease-standard),
            color var(--duration-fast) var(--ease-standard),
            opacity var(--duration-fast) var(--ease-standard);

        &:not(:disabled):hover {
            border-color: var(--color-border-strong);
            background: var(--color-surface-hover);
            color: var(--color-text-primary);
        }

        &--selected {
            border-color: var(--color-primary);
            background: var(--color-primary-subtle);
            color: var(--color-text-primary);
            box-shadow: inset 0 0 0 var(--border-width) var(--color-primary);
        }

        &--locked {
            border-color: color-mix(in srgb,
                    var(--color-border) 65%,
                    transparent);
            background: color-mix(in srgb,
                    var(--color-surface) 65%,
                    transparent);
            color: var(--color-text-muted);
            cursor: not-allowed;
            opacity: 0.52;
        }
    }

    &__number,
    &__requirement {
        font-size: var(--font-size-xs);
        line-height: var(--line-height-tight);
    }

    &__number {
        color: currentcolor;
        font-weight: var(--font-weight-semibold);
    }

    &__name {
        overflow: hidden;
        color: inherit;
        font-size: var(--font-size-sm);
        line-height: var(--line-height-tight);
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    &__requirement {
        color: var(--color-text-muted);
    }
}
</style>