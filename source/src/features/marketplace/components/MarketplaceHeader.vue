<script setup lang="ts">
import { computed } from 'vue'
import {
    Building2,
    Landmark,
    Star,
    CircleUserRound,
    X,
} from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import AppIconButton from '@/design-system/components/AppIconButton.vue'
import AppProgressBar from '@/design-system/components/AppProgressBar.vue'
import { usePortalActions } from '@/composables/usePortalActions'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { formatCurrency, formatNumber } from '@/utils/formatters'

const marketplaceStore = useMarketplaceStore()
const { requestPortalClose } = usePortalActions()
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

    const currentPoints = formatNumber(
        progress.points,
        locale.value,
    )

    if (progress.nextRankPoints === null) {
        return t('portal.header.scorePoints', {
            points: currentPoints,
        })
    }

    return t('portal.header.scoreProgressValue', {
        current: currentPoints,
        next: formatNumber(
            progress.nextRankPoints,
            locale.value,
        ),
    })
})
</script>

<template>
    <header v-if="profile" class="marketplace-header">
        <section class="marketplace-header__identity">
            <Building2 class="marketplace-header__logo" :size="42" :stroke-width="1.8" aria-hidden="true" />

            <div class="marketplace-header__brand">
                <strong class="marketplace-header__city">
                    {{ t('portal.header.city') }}
                </strong>

                <span class="marketplace-header__portal-name">
                    {{ t('portal.header.portalName') }}
                </span>
            </div>

            <div class="marketplace-header__separator" />

            <div class="marketplace-header__exchange">
                <strong>
                    {{ t('portal.header.exchangeName') }}
                </strong>

                <span>
                    {{ t('portal.header.tagline') }}
                </span>
            </div>
        </section>

        <section class="marketplace-header__account">
            <div class="marketplace-header__account-item">
                <CircleUserRound class="marketplace-header__account-icon" :size="27" :stroke-width="2"
                    aria-hidden="true" />

                <div class="marketplace-header__account-content">
                    <strong class="marketplace-header__account-value">
                        {{ profile.characterName }}
                    </strong>

                    <span class="marketplace-header__account-label">
                        {{ profile.investorProgress.rank }}
                    </span>
                </div>
            </div>

            <div class="marketplace-header__separator" />

            <div class="marketplace-header__account-item">
                <Landmark class="marketplace-header__account-icon" :size="25" aria-hidden="true" />

                <div class="marketplace-header__account-content">
                    <span class="marketplace-header__account-label">
                        {{ t('portal.header.bankBalance') }}
                    </span>

                    <strong class="marketplace-header__account-value">
                        {{ formattedBankBalance }}
                    </strong>
                </div>
            </div>

            <div class="marketplace-header__separator" />

            <div class="
          marketplace-header__account-item
          marketplace-header__account-item--score
        ">
                <Star class="
            marketplace-header__account-icon
            marketplace-header__account-icon--score
          " :size="25" fill="currentColor" aria-hidden="true" />

                <div class="marketplace-header__score-content">
                    <div class="marketplace-header__score-heading">
                        <span class="marketplace-header__account-label">
                            {{ t('portal.header.investorScore') }}
                        </span>

                        <strong class="marketplace-header__account-value">
                            {{ formattedInvestorScore }}
                        </strong>
                    </div>

                    <AppProgressBar :value="profile.investorProgress.percentage" :max="100"
                        :label="t('portal.header.investorScoreProgress')" />
                </div>
            </div>

            <div class="marketplace-header__separator" />

            <AppIconButton variant="ghost" :label="t('common.close')" @click="requestPortalClose">
                <X :size="25" aria-hidden="true" />
            </AppIconButton>
        </section>
    </header>
</template>

<style scoped lang="scss">
.marketplace-header {
    display: flex;
    min-height: 4.75rem;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-8);
    padding: var(--space-3) var(--space-6);
    border-bottom: var(--border-width) solid var(--color-border);
    background: var(--color-surface);
    box-shadow: var(--shadow-surface);

    &__identity,
    &__account,
    &__account-item,
    &__score-heading {
        display: flex;
        align-items: center;
    }

    &__identity {
        min-width: 0;
        gap: var(--space-4);
    }

    &__logo {
        flex: 0 0 auto;
        color: var(--color-text-primary);
    }

    &__brand {
        display: grid;
        flex: 0 0 auto;
        gap: 0.125rem;
    }

    &__city {
        color: var(--color-text-primary);
        font-size: var(--font-size-xl);
        font-weight: var(--font-weight-bold);
        letter-spacing: 0.08em;
        line-height: var(--line-height-tight);
        text-transform: uppercase;
    }

    &__portal-name {
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        font-weight: var(--font-weight-semibold);
        letter-spacing: 0.22em;
        line-height: var(--line-height-tight);
        text-transform: uppercase;
    }

    &__separator {
        width: var(--border-width);
        height: 2.75rem;
        flex: 0 0 auto;
        background: var(--color-border-strong);
    }

    &__exchange {
        display: grid;
        gap: var(--space-1);
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        line-height: var(--line-height-tight);

        strong {
            color: var(--color-text-primary);
            font-weight: var(--font-weight-medium);
        }
    }

    &__account {
        min-width: 0;
        justify-content: flex-end;
        gap: var(--space-5);
    }

    &__account-item {
        min-width: 0;
        gap: var(--space-3);

        &--score {
            width: 17rem;
        }
    }

    &__account-icon {
        flex: 0 0 auto;
        color: var(--color-text-secondary);

        &--score {
            color: var(--color-warning);
        }
    }

    &__account-content {
        display: grid;
        min-width: 0;
        gap: var(--space-1);
    }

    &__account-label {
        display: block;
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        line-height: var(--line-height-tight);
        white-space: nowrap;
    }

    &__account-value {
        display: block;
        overflow: hidden;
        color: var(--color-text-primary);
        font-size: var(--font-size-sm);
        line-height: var(--line-height-tight);
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    &__score-content {
        display: grid;
        width: 100%;
        gap: var(--space-2);
    }

    &__score-heading {
        justify-content: space-between;
        gap: var(--space-3);
    }
}

@media (max-width: 90rem), (max-height: 50rem) {
    .marketplace-header {
        gap: var(--space-4);
        padding-inline: var(--space-4);

        &__exchange {
            display: none;
        }

        &__identity,
        &__account {
            gap: var(--space-3);
        }

        &__account-item--score {
            width: 14rem;
        }
    }
}
</style>