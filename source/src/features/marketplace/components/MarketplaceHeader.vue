<script setup lang="ts">
import { computed } from 'vue'
import { Building2, Landmark, Star, UserRound } from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import AppProgressBar from '@/design-system/components/AppProgressBar.vue'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { formatCurrency, formatNumber } from '@/utils/formatters'

const marketplaceStore = useMarketplaceStore()
const { locale, t } = useI18n()

const profile = computed(() => marketplaceStore.profile)

const formattedBankBalance = computed(() => {
    if (!profile.value) return ''

    return formatCurrency(
        profile.value.bankBalance,
        marketplaceStore.currencySymbol,
        locale.value,
    )
})

const formattedInvestorScore = computed(() => {
    const progress = profile.value?.investorProgress
    if (!progress) return ''

    const currentPoints = formatNumber(progress.points, locale.value)

    if (progress.nextRankPoints === null) {
        return currentPoints
    }

    return `${currentPoints} / ${formatNumber(
        progress.nextRankPoints,
        locale.value,
    )}`
})
</script>

<template>
    <header v-if="profile" class="marketplace-header">
        <div class="marketplace-header__identity">
            <div class="marketplace-header__brand-icon">
                <Building2 :size="30" aria-hidden="true" />
            </div>

            <div class="marketplace-header__brand">
                <strong class="marketplace-header__city">
                    {{ t('portal.header.city') }}
                </strong>

                <span class="marketplace-header__portal-name">
                    {{ t('portal.header.portalName') }}
                </span>
            </div>

            <div class="marketplace-header__divider" />

            <p class="marketplace-header__tagline">
                {{ t('portal.header.tagline') }}
            </p>
        </div>

        <div class="marketplace-header__information">
            <section class="marketplace-header__information-item">
                <div class="marketplace-header__information-icon">
                    <UserRound :size="21" aria-hidden="true" />
                </div>

                <div>
                    <span class="marketplace-header__label">
                        {{ t('portal.header.investor') }}
                    </span>

                    <strong class="marketplace-header__value">
                        {{ profile.characterName }}
                    </strong>

                    <span class="marketplace-header__supporting-value">
                        {{ profile.investorProgress.rank }}
                    </span>
                </div>
            </section>

            <section class="marketplace-header__information-item">
                <div class="marketplace-header__information-icon">
                    <Landmark :size="21" aria-hidden="true" />
                </div>

                <div>
                    <span class="marketplace-header__label">
                        {{ t('portal.header.bankBalance') }}
                    </span>

                    <strong class="marketplace-header__value">
                        {{ formattedBankBalance }}
                    </strong>
                </div>
            </section>

            <section class="
          marketplace-header__information-item
          marketplace-header__information-item--progress
        ">
                <div class="marketplace-header__information-icon">
                    <Star :size="21" aria-hidden="true" />
                </div>

                <div class="marketplace-header__progress-content">
                    <div class="marketplace-header__progress-heading">
                        <span class="marketplace-header__label">
                            {{ t('portal.header.investorScore') }}
                        </span>

                        <strong class="marketplace-header__score">
                            {{ formattedInvestorScore }}
                        </strong>
                    </div>

                    <AppProgressBar :value="profile.investorProgress.percentage" :max="100"
                        :label="t('portal.header.investorScoreProgress')" />
                </div>
            </section>
        </div>
    </header>
</template>

<style scoped lang="scss">
.marketplace-header {
    display: flex;
    min-height: 5rem;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-8);
    padding: var(--space-4) var(--space-6);
    border-bottom: var(--border-width) solid var(--color-border);
    background: var(--color-surface);
    box-shadow: var(--shadow-surface);

    &__identity,
    &__information,
    &__information-item,
    &__progress-heading {
        display: flex;
        align-items: center;
    }

    &__identity {
        min-width: 0;
        gap: var(--space-4);
    }

    &__brand-icon {
        display: grid;
        width: 3rem;
        height: 3rem;
        flex: 0 0 auto;
        place-items: center;
        border: var(--border-width) solid var(--color-border-strong);
        border-radius: var(--radius-md);
        background: var(--color-primary-subtle);
        color: var(--color-primary);
    }

    &__brand {
        display: grid;
        flex: 0 0 auto;
        gap: 0.125rem;
    }

    &__city {
        color: var(--color-text-primary);
        font-size: var(--font-size-lg);
        letter-spacing: var(--letter-spacing-heading);
        line-height: var(--line-height-tight);
    }

    &__portal-name {
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        font-weight: var(--font-weight-semibold);
        letter-spacing: 0.18em;
        line-height: var(--line-height-tight);
        text-transform: uppercase;
    }

    &__divider {
        width: var(--border-width);
        height: 2.5rem;
        flex: 0 0 auto;
        background: var(--color-border);
    }

    &__tagline {
        max-width: 12rem;
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        line-height: var(--line-height-normal);
    }

    &__information {
        justify-content: flex-end;
    }

    &__information-item {
        min-height: 3rem;
        gap: var(--space-3);
        padding-inline: var(--space-6);
        border-left: var(--border-width) solid var(--color-border);

        &:last-child {
            padding-right: 0;
        }

        &--progress {
            width: 18rem;
        }
    }

    &__information-icon {
        display: grid;
        flex: 0 0 auto;
        place-items: center;
        color: var(--color-primary);
    }

    &__label,
    &__supporting-value {
        display: block;
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        line-height: var(--line-height-tight);
    }

    &__value {
        display: block;
        margin-top: var(--space-1);
        color: var(--color-text-primary);
        font-size: var(--font-size-sm);
        line-height: var(--line-height-tight);
    }

    &__supporting-value {
        margin-top: var(--space-1);
        color: var(--color-primary);
    }

    &__progress-content {
        display: grid;
        width: 100%;
        gap: var(--space-2);
    }

    &__progress-heading {
        justify-content: space-between;
        gap: var(--space-4);
    }

    &__score {
        flex: 0 0 auto;
        color: var(--color-text-primary);
        font-size: var(--font-size-xs);
    }
}

@media (max-width: 75rem) {
    .marketplace-header {

        &__tagline,
        &__divider {
            display: none;
        }

        &__information-item {
            padding-inline: var(--space-4);

            &--progress {
                width: 15rem;
            }
        }
    }
}
</style>