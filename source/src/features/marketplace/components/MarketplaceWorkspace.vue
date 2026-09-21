<script setup lang="ts">
import { Map } from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import AppSurface from '@/design-system/components/AppSurface.vue'

import BusinessLocationList from './BusinessLocationList.vue'

const { t } = useI18n()
</script>

<template>
    <section class="marketplace-workspace">
        <BusinessLocationList />

        <AppSurface class="marketplace-workspace__map" elevation="raised">
            <Map :size="42" :stroke-width="1.5" aria-hidden="true" />

            <div>
                <h2>{{ t('portal.mapPlaceholder.title') }}</h2>
                <p>{{ t('portal.mapPlaceholder.description') }}</p>
            </div>
        </AppSurface>
    </section>
</template>

<style scoped lang="scss">
.marketplace-workspace {
    display: grid;
    min-width: 0;
    min-height: 0;
    grid-template-columns:
        minmax(20rem, 3fr) minmax(0, 7fr);
    gap: var(--space-4);
    padding:
        var(--space-4) var(--space-6) var(--space-6);

    &__map {
        display: grid;
        min-width: 0;
        min-height: 0;
        align-content: center;
        justify-items: center;
        gap: var(--space-4);
        color: var(--color-text-muted);
        text-align: center;

        h2 {
            color: var(--color-text-primary);
            font-size: var(--font-size-lg);
        }

        p {
            margin-top: var(--space-2);
            color: var(--color-text-secondary);
            font-size: var(--font-size-sm);
        }
    }
}
</style>