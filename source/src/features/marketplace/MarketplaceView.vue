<script setup lang="ts">
import BusinessTierSelector from './components/BusinessTierSelector.vue'
import MarketplaceHeader from './components/MarketplaceHeader.vue'
</script>

<template>
    <main class="marketplace-view">
        <MarketplaceHeader />
        <BusinessTierSelector />

        <section class="marketplace-view__workspace" aria-label="Marketplace workspace" />
    </main>
</template>

<style scoped lang="scss">
.marketplace-view {
    display: grid;
    width: 100%;
    height: 100%;
    grid-template-rows: auto auto minmax(0, 1fr);
    background: var(--color-background);

    &__workspace {
        min-height: 0;
    }
}
</style>