<script setup lang="ts">
import { defineAsyncComponent, onMounted } from 'vue'

import { useUiStore } from '@/shared/stores/ui.store'
import { useUiLifecycle } from '@/shared/composables/useUiLifecycle'
import { isFiveMEnvironment } from '@/integrations/nui'

const PortalView = defineAsyncComponent(
    () => import('@/portal/PortalView.vue'),
)

const CashCounterView = defineAsyncComponent(
    () => import('@/cash-counter/CashCounterView.vue'),
)

const RaidView = defineAsyncComponent(
    () => import('@/raid/RaidView.vue'),
)

const ReviewView = defineAsyncComponent(
    () => import('@/review/ReviewView.vue'),
)

const ui = useUiStore()

useUiLifecycle()

onMounted(async () => {
    if (!import.meta.env.DEV || isFiveMEnvironment()) return

    const screen = new URLSearchParams(window.location.search).get('screen')

    if (screen !== 'review') return

    const { useReviewStore } = await import(
        '@/review/stores/review.store'
    )

    useReviewStore().open()
})
</script>

<template>
    <PortalView v-if="ui.activeScreen === 'marketplace'" />

    <CashCounterView v-else-if="ui.activeScreen === 'cash-counter'" />

    <RaidView v-else-if="ui.activeScreen === 'raid'" />

    <ReviewView v-else-if="ui.activeScreen === 'review'" />
</template>