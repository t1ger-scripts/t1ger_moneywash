<script setup lang="ts">
import BusinessTierSelector from './components/BusinessTierSelector.vue'
import MarketplaceHeader from './components/MarketplaceHeader.vue'
import MarketplaceWorkspace from './components/MarketplaceWorkspace.vue'
</script>

<template>
    <main class="marketplace-view">
        <MarketplaceHeader />
        <BusinessTierSelector />
        <MarketplaceWorkspace />
    </main>
</template>

<style scoped lang="scss">
.marketplace-view {
    display: grid;
    width: 100%;
    height: 100%;
    overflow: hidden;
    grid-template-rows:
        auto auto minmax(0, 1fr);
    background: var(--color-background);
}
</style>