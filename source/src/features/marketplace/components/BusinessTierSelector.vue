<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

import type { BusinessTier } from '@/domain/marketplace'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { formatNumber } from '@/utils/formatters'

import BusinessTypeIcon from './BusinessTypeIcon.vue'

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
        <div class="tier-selector__track app-scrollbar">
            <button v-for="tier in tiers" :key="tier.businessType" class="tier-selector__item" :class="{
                'tier-selector__item--accessible': isTierAccessible(tier),
                'tier-selector__item--selected': isTierSelected(tier),
                'tier-selector__item--locked': !isTierAccessible(tier),
            }" type="button" :disabled="!isTierAccessible(tier)" :aria-pressed="isTierSelected(tier)"
                :aria-label="createTierLabel(tier)" @click="selectTier(tier)">
                <span class="tier-selector__icon">
                    <BusinessTypeIcon :business-type="tier.businessType" :size="26" :stroke-width="2.1" />
                </span>

                <span class="tier-selector__content">
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
        grid-template-columns: repeat(9, minmax(9.5rem, 1fr));
        gap: var(--space-2);
        padding-bottom: var(--space-1);
    }

    &__item {
        display: flex;
        min-height: 4.75rem;
        align-items: center;
        gap: var(--space-2);
        padding: var(--space-3);
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

        &--accessible {
            .tier-selector__icon {
                color: var(--color-text-secondary);
            }

            .tier-selector__requirement {
                color: var(--color-text-muted);
            }
        }

        &--selected {
            border-color: var(--color-primary);
            background: var(--color-primary-subtle);
            color: var(--color-text-primary);
            box-shadow: inset 0 0 0 var(--border-width) var(--color-primary);

            .tier-selector__icon,
            .tier-selector__requirement {
                color: var(--color-primary);
            }
        }

        &--locked {
            background: color-mix(in srgb,
                    var(--color-surface) 65%,
                    transparent);
            color: var(--color-text-muted);
            cursor: not-allowed;
            opacity: 0.52;

            .tier-selector__icon,
            .tier-selector__requirement {
                color: var(--color-text-muted);
            }
        }
    }

    &__icon {
        display: grid;
        width: 2.25rem;
        height: 2.25rem;
        flex: 0 0 auto;
        place-items: center;
        color: var(--color-text-muted);
    }

    &__content {
        display: grid;
        min-width: 0;
        gap: var(--space-1);
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
        font-size: var(--font-size-xs);
        line-height: var(--line-height-tight);
    }
}

@media (max-width: 90rem), (max-height: 50rem) {
    .tier-selector {
        padding: var(--space-3) var(--space-4);

        &__track {
            grid-template-columns:
                repeat(9, minmax(9.25rem, 1fr));
        }
    }
}

</style>