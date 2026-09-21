<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Building2 } from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import AppBadge from '@/design-system/components/AppBadge.vue'
import type { BusinessLocation } from '@/domain/marketplace'
import { formatCurrency } from '@/utils/formatters'

const props = defineProps<{
    location: BusinessLocation
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

            <Building2 v-else :size="25" :stroke-width="1.7" aria-hidden="true" />
        </span>

        <span class="business-list-item__content">
            <strong class="business-list-item__name">
                {{ location.displayName }}
            </strong>

            <span class="business-list-item__location">
                {{ locationLabel }}
            </span>
        </span>

        <AppBadge v-if="location.ownership === 'ownedByPlayer'" tone="success" shape="rounded">
            {{ t('portal.businessList.owned') }}
        </AppBadge>

        <AppBadge v-else tone="primary" shape="rounded">
            {{ formattedPrice }}
        </AppBadge>
    </button>
</template>

<style scoped lang="scss">
.business-list-item {
    display: grid;
    width: 100%;
    min-height: 4.75rem;
    grid-template-columns:
        7.25rem minmax(0, 1fr) auto;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2);
    border: var(--border-width) solid transparent;
    border-bottom-color: var(--color-border);
    border-radius: 0;
    background: transparent;
    color: var(--color-text-primary);
    cursor: pointer;
    text-align: left;
    transition:
        border-color var(--duration-fast) var(--ease-standard),
        border-radius var(--duration-fast) var(--ease-standard),
        background-color var(--duration-fast) var(--ease-standard);

    &:hover {
        background: var(--color-surface-hover);
    }

    &--selected {
        border-color: var(--color-primary);
        border-radius: var(--radius-sm);
        background: var(--color-primary-subtle);
    }

    &--owned {
        .business-list-item__thumbnail {
            color: var(--color-success);
        }
    }

    &__thumbnail {
        display: grid;
        height: 3.75rem;
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
        gap: var(--space-1);
    }

    &__name,
    &__location {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    &__name {
        color: var(--color-text-primary);
        font-size: var(--font-size-sm);
        line-height: var(--line-height-tight);
    }

    &__location {
        color: var(--color-text-secondary);
        font-size: var(--font-size-xs);
        line-height: var(--line-height-tight);
    }
}
</style>