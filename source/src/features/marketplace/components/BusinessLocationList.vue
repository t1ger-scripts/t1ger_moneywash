<script setup lang="ts">
import { computed } from 'vue'
import { Building2, SearchX } from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import AppBadge from '@/design-system/components/AppBadge.vue'
import AppSearchInput from '@/design-system/components/AppSearchInput.vue'
import AppSurface from '@/design-system/components/AppSurface.vue'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { formatNumber } from '@/utils/formatters'

import BusinessLocationListItem from './BusinessLocationListItem.vue'

const marketplaceStore = useMarketplaceStore()
const { locale, t } = useI18n()

const selectedTier = computed(
    () => marketplaceStore.selectedTier,
)

const locations = computed(
    () => marketplaceStore.filteredLocations,
)

const availabilitySummary = computed(() => {
    const tier = selectedTier.value
    if (!tier) return ''

    return t('portal.businessList.availability', {
        available: formatNumber(
            tier.availableLocationCount,
            locale.value,
        ),
        total: formatNumber(
            tier.totalLocationCount,
            locale.value,
        ),
    })
})

const emptyStateTranslation = computed(() => {
    if (marketplaceStore.selectedTierLocations.length === 0) {
        return 'portal.businessList.noLocations'
    }

    return 'portal.businessList.noSearchResults'
})

function selectLocation(locationId: string): void {
    marketplaceStore.selectLocation(locationId)
}

function updateSearchQuery(value: string): void {
    marketplaceStore.setSearchQuery(value)
}
</script>

<template>
    <AppSurface v-if="selectedTier" class="business-list">
        <header class="business-list__header">
            <div class="business-list__title-row">
                <div>
                    <div class="business-list__title">
                        <h2>{{ selectedTier.displayName }}</h2>

                        <AppBadge tone="primary">
                            {{
                                t('portal.tierSelector.tier', {
                                    number: selectedTier.tierNumber,
                                })
                            }}
                        </AppBadge>
                    </div>

                    <p>{{ availabilitySummary }}</p>
                </div>
            </div>

            <AppSearchInput :model-value="marketplaceStore.searchQuery" :label="t('portal.businessList.searchLabel')"
                :placeholder="t('portal.businessList.searchPlaceholder')"
                :clear-label="t('portal.businessList.clearSearch')" @update:model-value="updateSearchQuery" />
        </header>

        <div v-if="locations.length > 0" class="business-list__locations">
            <BusinessLocationListItem v-for="location in locations" :key="location.id" :location="location"
                :tier-name="selectedTier.displayName" :currency-symbol="marketplaceStore.currencySymbol" :selected="marketplaceStore.selectedLocationId === location.id
                    " @select="selectLocation" />
        </div>

        <div v-else class="business-list__empty">
            <SearchX v-if="marketplaceStore.searchQuery" :size="30" aria-hidden="true" />

            <Building2 v-else :size="30" aria-hidden="true" />

            <p>{{ t(emptyStateTranslation) }}</p>
        </div>
    </AppSurface>
</template>

<style scoped lang="scss">
.business-list {
    display: grid;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    grid-template-rows: auto minmax(0, 1fr);

    &__header {
        display: grid;
        gap: var(--space-4);
        padding: var(--space-5);
        border-bottom: var(--border-width) solid var(--color-border);
    }

    &__title-row {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: var(--space-4);

        p {
            margin-top: var(--space-2);
            color: var(--color-text-secondary);
            font-size: var(--font-size-xs);
        }
    }

    &__title {
        display: flex;
        align-items: center;
        gap: var(--space-3);

        h2 {
            color: var(--color-text-primary);
            font-size: var(--font-size-lg);
            line-height: var(--line-height-tight);
        }
    }

    &__locations {
        min-height: 0;
        overflow-y: auto;
        padding: var(--space-2);
        scrollbar-width: thin;
        scrollbar-color:
            var(--color-border-strong) transparent;
    }

    &__empty {
        display: grid;
        min-height: 12rem;
        align-content: center;
        justify-items: center;
        gap: var(--space-3);
        padding: var(--space-6);
        color: var(--color-text-muted);
        text-align: center;

        p {
            max-width: 18rem;
            font-size: var(--font-size-sm);
            line-height: var(--line-height-normal);
        }
    }
}
</style>