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

import AppIconButton from '@/portal/components/ui/AppIconButton.vue'
import AppProgressBar from '@/portal/components/ui/AppProgressBar.vue'
import { usePortalActions } from '@/portal/composables/usePortalActions'
import { usePortalFormat } from '@/portal/composables/usePortalFormat'
import { usePortalStore } from '@/portal/stores/portal.store'

const portalStore = usePortalStore()
const { requestPortalClose } = usePortalActions()
const { t } = useI18n()
const { formatCount, formatMoney } = usePortalFormat()

const profile = computed(() => portalStore.profile)

const formattedBankBalance = computed(() => {
    if (!profile.value) return ''

    return formatMoney(profile.value.bankBalance)
})

const formattedInvestorScore = computed(() => {
    const progress = profile.value?.investorProgress
    if (!progress) return ''

    const currentPoints = formatCount(progress.points)

    if (progress.nextRankPoints == null) {
        return t('portal.header.scorePoints', {
            points: currentPoints,
        })
    }

    return t('portal.header.scoreProgressValue', {
        current: currentPoints,
        next: formatCount(progress.nextRankPoints),
    })
})
</script>

<template>
    <header v-if="profile" class="portal-header">
        <section class="portal-header__identity">
            <Building2 class="portal-header__logo" :size="42" :stroke-width="1.8" aria-hidden="true" />

            <div class="portal-header__brand">
                <strong class="portal-header__city">
                    {{ t('portal.header.city') }}
                </strong>

                <span class="portal-header__portal-name">
                    {{ t('portal.header.portalName') }}
                </span>
            </div>

            <div class="portal-header__separator" />

            <div class="portal-header__exchange">
                <strong>
                    {{ t('portal.header.exchangeName') }}
                </strong>

                <span>
                    {{ t('portal.header.tagline') }}
                </span>
            </div>
        </section>

        <section class="portal-header__account">
            <div class="portal-header__account-item">
                <CircleUserRound class="portal-header__account-icon" :size="27" :stroke-width="2"
                    aria-hidden="true" />

                <div class="portal-header__account-content">
                    <strong class="portal-header__account-value">
                        {{ profile.characterName }}
                    </strong>

                    <span class="portal-header__account-label">
                        {{ profile.investorProgress.rank }}
                    </span>
                </div>
            </div>

            <div class="portal-header__separator" />

            <div class="portal-header__account-item">
                <Landmark class="portal-header__account-icon" :size="25" aria-hidden="true" />

                <div class="portal-header__account-content">
                    <span class="portal-header__account-label">
                        {{ t('portal.header.bankBalance') }}
                    </span>

                    <strong class="portal-header__account-value">
                        {{ formattedBankBalance }}
                    </strong>
                </div>
            </div>

            <div class="portal-header__separator" />

            <div class="portal-header__account-item portal-header__account-item--score">
                <Star class="portal-header__account-icon portal-header__account-icon--score" :size="25"
                    fill="currentColor" aria-hidden="true" />

                <div class="portal-header__score-content">
                    <div class="portal-header__score-heading">
                        <span class="portal-header__account-label">
                            {{ t('portal.header.investorScore') }}
                        </span>

                        <strong class="portal-header__account-value">
                            {{ formattedInvestorScore }}
                        </strong>
                    </div>

                    <AppProgressBar :value="profile.investorProgress.percentage"
                        :label="t('portal.header.investorScoreProgress')" />
                </div>
            </div>

            <div class="portal-header__separator" />

            <AppIconButton variant="ghost" :label="t('common.close')" @click="requestPortalClose">
                <X :size="25" aria-hidden="true" />
            </AppIconButton>
        </section>
    </header>
</template>

<style scoped lang="scss">
.portal-header {
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

@container portal (max-width: 80rem) {
    .portal-header {
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