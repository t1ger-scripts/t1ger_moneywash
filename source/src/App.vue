<script setup lang="ts">
import { defineAsyncComponent } from 'vue'

import { useUiStore } from '@/shared/stores/ui.store'
import { useUiLifecycle } from '@/shared/composables/useUiLifecycle'

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
</script>

<template>
    <PortalView v-if="ui.activeScreen === 'portal'" />

    <CashCounterView v-else-if="ui.activeScreen === 'cash-counter'" />

    <RaidView v-else-if="ui.activeScreen === 'raid'" />

    <ReviewView v-else-if="ui.activeScreen === 'review'" />
</template>