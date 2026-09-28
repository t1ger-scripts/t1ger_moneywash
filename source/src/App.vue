<script setup lang="ts">
import { defineAsyncComponent } from 'vue'
import { useUiStore } from '@/stores/ui.store'
import { useUiLifecycle } from '@/composables/useUiLifecycle'
const MarketplaceScreen = defineAsyncComponent(
    () => import('@/features/marketplace/MarketplaceScreen.vue'),
)
const CashCounterView = defineAsyncComponent(
    () => import('@/features/cash-counter/CashCounterView.vue'),
)
const ui = useUiStore()
useUiLifecycle()
</script>
<template>
    <MarketplaceScreen v-if="ui.activeScreen === 'marketplace'" />
    <CashCounterView v-else-if="ui.activeScreen === 'cash-counter'" />
</template>
