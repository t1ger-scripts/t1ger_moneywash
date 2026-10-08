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

const ui = useUiStore()

useUiLifecycle()
</script>

<template>
    <PortalView v-if="ui.activeScreen === 'marketplace'" />

    <CashCounterView v-else-if="ui.activeScreen === 'cash-counter'" />
</template>