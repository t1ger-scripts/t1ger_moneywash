<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import {
    Building2,
    ChartColumn,
    Coins,
    MapPin,
    Navigation,
    ShoppingCart,
    Star,
} from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import { usePortalActions } from '@/composables/usePortalActions'
import AppBadge from '@/design-system/components/AppBadge.vue'
import AppButton from '@/design-system/components/AppButton.vue'
import AppSurface from '@/design-system/components/AppSurface.vue'
import type { PurchaseBlockReason } from '@/stores/marketplace.store'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import {
    formatCurrency,
    formatNumber,
} from '@/utils/formatters'

import BusinessTypeIcon from './BusinessTypeIcon.vue'

const marketplaceStore = useMarketplaceStore()
const { requestBusinessWaypoint } = usePortalActions()
const { locale, t } = useI18n()

const imageFailed = ref(false)

const selectedLocation = computed(
    () => marketplaceStore.selectedLocation,
)

const selectedTier = computed(
    () => marketplaceStore.selectedTier,
)

const imageSource = computed(() => {
    const fileName = selectedLocation.value?.imageFileName?.trim()

    if (!fileName || imageFailed.value) {
        return null
    }

    return `./images/businesses/${encodeURIComponent(fileName)}`
})

const fullStreet = computed(() => {
    const address = selectedLocation.value?.address

    if (!address) {
        return t('portal.businessDetails.unknownStreet')
    }

    if (address.street && address.crossingRoad) {
        return `${address.street} / ${address.crossingRoad}`
    }

    return address.street
        ?? t('portal.businessDetails.unknownStreet')
})

const zone = computed(
    () =>
        selectedLocation.value?.address.zone
        ?? t('portal.businessDetails.unknownZone'),
)

const formattedPrice = computed(() => {
    const location = selectedLocation.value
    if (!location) return ''

    return formatCurrency(
        location.price,
        marketplaceStore.currencySymbol,
        locale.value,
    )
})

const formattedRevenue = computed(() => {
    const tier = selectedTier.value
    if (!tier) return ''

    return formatCurrency(
        tier.projectedRevenue,
        marketplaceStore.currencySymbol,
        locale.value,
    )
})

const purchaseBlockReason = computed(
    (): PurchaseBlockReason | null => {
        const location = selectedLocation.value

        if (!location || location.ownership === 'ownedByPlayer') {
            return null
        }

        return marketplaceStore.getPurchaseBlockReason(location)
    },
)

const purchaseBlockTranslationKeys: Record<
    PurchaseBlockReason,
    string
> = {
    alreadyOwnsBusiness:
        'portal.businessDetails.purchaseBlocked.alreadyOwnsBusiness',
    insufficientFunds:
        'portal.businessDetails.purchaseBlocked.insufficientFunds',
    tierLocked:
        'portal.businessDetails.purchaseBlocked.tierLocked',
    locationUnavailable:
        'portal.businessDetails.purchaseBlocked.locationUnavailable',
}

const purchaseBlockMessage = computed(() => {
    const reason = purchaseBlockReason.value

    return reason
        ? t(purchaseBlockTranslationKeys[reason])
        : ''
})

watch(
    () => selectedLocation.value?.id,
    () => {
        imageFailed.value = false
    },
)

function handleImageError(): void {
    imageFailed.value = true
}

function openPurchaseDialog(): void {
    const location = selectedLocation.value
    if (!location) return

    marketplaceStore.openPurchaseDialog(location.id)
}

async function setWaypoint(): Promise<void> {
    const location = selectedLocation.value
    if (!location) return

    await requestBusinessWaypoint(location)
}
</script>

<template>
    <AppSurface class="business-details" :aria-label="t('portal.businessDetails.ariaLabel')">
        <template v-if="selectedLocation && selectedTier">
            <div class="business-details__image">
                <img v-if="imageSource" :src="imageSource" :alt="selectedLocation.displayName"
                    @error="handleImageError" />

                <div v-else class="business-details__image-placeholder">
                    <BusinessTypeIcon :business-type="selectedLocation.businessType" :size="42" :stroke-width="1.5" />
                </div>
            </div>

            <div class="business-details__content">
                <header class="business-details__header">
                    <h2>{{ selectedLocation.displayName }}</h2>

                    <AppBadge :tone="selectedLocation.ownership === 'ownedByPlayer'
                            ? 'success'
                            : 'primary'
                        " shape="rounded">
                        {{
                            selectedLocation.ownership === 'ownedByPlayer'
                                ? t('portal.businessDetails.owned')
                                : t('portal.businessDetails.available')
                        }}
                    </AppBadge>
                </header>

                <div class="business-details__location">
                    <span>
                        <MapPin :size="18" aria-hidden="true" />
                        {{ fullStreet }}
                    </span>

                    <span>
                        <Building2 :size="18" aria-hidden="true" />
                        {{ zone }}

                        <AppBadge tone="primary" shape="rounded">
                            {{
                                t('portal.tierSelector.tier', {
                                    number: selectedTier.tierNumber,
                                })
                            }}
                        </AppBadge>
                    </span>
                </div>

                <div class="business-details__price">
                    <span>
                        {{ t('portal.businessDetails.acquisitionPrice') }}
                    </span>

                    <strong>{{ formattedPrice }}</strong>
                </div>

                <dl class="business-details__metrics">
                    <div>
                        <dt>
                            <ChartColumn :size="19" aria-hidden="true" />
                            {{ t('portal.businessDetails.projectedRevenue') }}
                        </dt>

                        <dd>
                            {{
                                t('portal.businessDetails.revenueCycle', {
                                    amount: formattedRevenue,
                                })
                            }}
                        </dd>
                    </div>

                    <div>
                        <dt>
                            <Coins :size="19" aria-hidden="true" />
                            {{ t('portal.businessDetails.operatingFee') }}
                        </dt>

                        <dd>
                            {{
                                t('portal.businessDetails.operatingFeeValue', {
                                    percentage:
                                        selectedTier.operatingFeePercentage,
                                })
                            }}
                        </dd>
                    </div>

                    <div>
                        <dt>
                            <Star :size="19" aria-hidden="true" />
                            {{
                                t(
                                    'portal.businessDetails.requiredInvestorScore',
                                )
                            }}
                        </dt>

                        <dd>
                            {{
                                t('portal.businessDetails.investorScoreValue', {
                                    points: formatNumber(
                                        selectedTier.requiredInvestorScore,
                                        locale,
                                    ),
                                })
                            }}
                        </dd>
                    </div>
                </dl>

                <div class="business-details__actions">
                    <AppButton v-if="
                        selectedLocation.ownership === 'ownedByPlayer'
                    " variant="secondary" size="large" block @click="setWaypoint">
                        <Navigation :size="19" aria-hidden="true" />
                        {{ t('portal.businessDetails.setWaypoint') }}
                    </AppButton>

                    <template v-else>
                        <AppButton size="large" block :disabled="purchaseBlockReason !== null"
                            @click="openPurchaseDialog">
                            <ShoppingCart :size="20" aria-hidden="true" />
                            {{ t('portal.businessDetails.purchase') }}
                        </AppButton>

                        <p v-if="purchaseBlockMessage" class="business-details__blocked-reason">
                            {{ purchaseBlockMessage }}
                        </p>
                    </template>
                </div>
            </div>
        </template>

        <div v-else class="business-details__empty">
            <Building2 :size="36" :stroke-width="1.5" />

            <h2>
                {{ t('portal.businessDetails.noSelectionTitle') }}
            </h2>

            <p>
                {{ t('portal.businessDetails.noSelectionDescription') }}
            </p>
        </div>
    </AppSurface>
</template>

<style scoped lang="scss">
.business-details {
    display: grid;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    grid-template-rows: auto minmax(0, 1fr);

    &__image {
        min-height: 13rem;
        overflow: hidden;
        border-bottom: var(--border-width) solid var(--color-border);
        background: var(--color-surface-raised);

        img,
        &-placeholder {
            width: 100%;
            height: 100%;
            min-height: 13rem;
        }

        img {
            display: block;
            object-fit: cover;
        }
    }

    &__image-placeholder {
        display: grid;
        place-items: center;
        color: var(--color-text-muted);
        background:
            linear-gradient(145deg,
                var(--color-surface-raised),
                var(--color-surface-hover));
    }

    &__content {
        min-height: 0;
        overflow-y: auto;
        padding: var(--space-5);
        scrollbar-width: thin;
        scrollbar-color: var(--color-border-strong) transparent;
    }

    &__header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: var(--space-3);

        h2 {
            min-width: 0;
            color: var(--color-text-primary);
            font-size: var(--font-size-xl);
            line-height: var(--line-height-tight);
        }
    }

    &__location {
        display: grid;
        gap: var(--space-2);
        margin-top: var(--space-4);
        color: var(--color-text-secondary);
        font-size: var(--font-size-sm);

        span {
            display: flex;
            min-width: 0;
            align-items: center;
            gap: var(--space-2);
        }

        svg {
            flex: 0 0 auto;
            color: var(--color-text-muted);
        }

        .app-badge {
            margin-left: auto;
        }
    }

    &__price {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: var(--space-4);
        margin-top: var(--space-5);
        padding: var(--space-4);
        border: var(--border-width) solid var(--color-primary);
        border-radius: var(--radius-md);
        background: var(--color-primary-subtle);

        span {
            color: var(--color-text-secondary);
            font-size: var(--font-size-sm);
        }

        strong {
            color: var(--color-primary-hover);
            font-size: var(--font-size-xl);
        }
    }

    &__metrics {
        margin: var(--space-4) 0 0;

        >div {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: var(--space-4);
            min-height: 3rem;
            border-bottom: var(--border-width) solid var(--color-border);
        }

        dt {
            display: flex;
            min-width: 0;
            align-items: center;
            gap: var(--space-3);
            color: var(--color-text-secondary);
            font-size: var(--font-size-sm);

            svg {
                flex: 0 0 auto;
                color: var(--color-text-muted);
            }
        }

        dd {
            flex: 0 0 auto;
            margin: 0;
            color: var(--color-text-primary);
            font-size: var(--font-size-sm);
            font-weight: var(--font-weight-semibold);
            text-align: right;
        }
    }

    &__actions {
        display: grid;
        gap: var(--space-3);
        margin-top: var(--space-5);
    }

    &__blocked-reason {
        color: var(--color-warning);
        font-size: var(--font-size-xs);
        line-height: var(--line-height-normal);
        text-align: center;
    }

    &__empty {
        display: grid;
        height: 100%;
        align-content: center;
        justify-items: center;
        gap: var(--space-3);
        padding: var(--space-6);
        color: var(--color-text-muted);
        text-align: center;

        h2 {
            color: var(--color-text-primary);
            font-size: var(--font-size-lg);
        }

        p {
            max-width: 18rem;
            font-size: var(--font-size-sm);
            line-height: var(--line-height-normal);
        }
    }
}
</style>