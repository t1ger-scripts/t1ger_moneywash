<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Building2, MapPin, Store } from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import AppBadge from '@/design-system/components/AppBadge.vue'
import type { BusinessLocation } from '@/domain/marketplace'
import { formatCurrency } from '@/utils/formatters'

const props = defineProps<{
    location: BusinessLocation
    tierName: string
    currencySymbol: string
    selected: boolean
}>()

const emit = defineEmits<{
    select: [locationId: string]
}>()

const { locale, t } = useI18n()
const imageFailed = ref(false)

const imageSource = computed(() => {
    const fileName = props.location.imageFileName?.trim()

    if (!fileName || imageFailed.value) {
        return null
    }

    return `./images/businesses/${encodeURIComponent(fileName)}`
})

const formattedPrice = computed(() =>
    formatCurrency(
        props.location.price,
        props.currencySymbol,
        locale.value,
    ),
)

const locationLabel = computed(
    () =>
        props.location.address.zone
        ?? props.location.address.street
        ?? t('portal.businessList.unknownLocation'),
)

watch(
    () => props.location.imageFileName,
    () => {
        imageFailed.value = false
    },
)

function handleImageError(): void {
    imageFailed.value = true
}
</script>

<template>
    <button class="business-list-item" :class="{
        'business-list-item--selected': selected,
        'business-list-item--owned':
            location.ownership === 'ownedByPlayer',
    }" type="button" :aria-pressed="selected" :aria-label="t('portal.businessList.selectLocation', {
        business: location.displayName,
    })
        " @click="emit('select', location.id)">
        <span class="business-list-item__thumbnail">
            <img v-if="imageSource" :src="imageSource" :alt="location.displayName" @error="handleImageError" />

            <Building2 v-else :size="27" :stroke-width="1.7" aria-hidden="true" />
        </span>

        <span class="business-list-item__content">
            <span class="business-list-item__heading">
                <strong class="business-list-item__name">
                    {{ location.displayName }}
                </strong>

                <AppBadge v-if="location.ownership === 'ownedByPlayer'" tone="success">
                    {{ t('portal.businessList.owned') }}
                </AppBadge>

                <AppBadge v-else tone="primary">
                    {{ formattedPrice }}
                </AppBadge>
            </span>

            <span class="business-list-item__metadata">
                <span>
                    <Store :size="14" aria-hidden="true" />
                    {{ tierName }}
                </span>

                <span>
                    <MapPin :size="14" aria-hidden="true" />
                    {{ locationLabel }}
                </span>
            </span>
        </span>
    </button>
</template>

<style scoped lang="scss">
.business-list-item {
    display: grid;
    width: 100%;
    min-height: 6rem;
    grid-template-columns: 6.5rem minmax(0, 1fr);
    gap: var(--space-3);
    padding: var(--space-3);
    border: var(--border-width) solid transparent;
    border-radius: var(--radius-md);
    background: transparent;
    color: var(--color-text-primary);
    cursor: pointer;
    text-align: left;
    transition:
        border-color var(--duration-fast) var(--ease-standard),
        background-color var(--duration-fast) var(--ease-standard);

    &:hover {
        border-color: var(--color-border);
        background: var(--color-surface-hover);
    }

    &--selected {
        border-color: var(--color-primary);
        background: var(--color-primary-subtle);
    }

    &--owned {
        .business-list-item__thumbnail {
            color: var(--color-success);
        }
    }

    &__thumbnail {
        display: grid;
        height: 4.5rem;
        overflow: hidden;
        place-items: center;
        border: var(--border-width) solid var(--color-border);
        border-radius: var(--radius-sm);
        background: var(--color-surface-raised);
        color: var(--color-text-muted);

        img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
    }

    &__content {
        display: grid;
        min-width: 0;
        align-content: center;
        gap: var(--space-2);
    }

    &__heading {
        display: flex;
        min-width: 0;
        align-items: center;
        justify-content: space-between;
        gap: var(--space-2);
    }

    &__name {
        overflow: hidden;
        font-size: var(--font-size-sm);
        line-height: var(--line-height-tight);
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    &__metadata {
        display: grid;
        gap: var(--space-1);
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);

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
    }
}
</style>