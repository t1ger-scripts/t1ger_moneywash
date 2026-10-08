<script setup lang="ts">
import BusinessLocationDetails from './BusinessLocationDetails.vue'
import BusinessLocationList from './BusinessLocationList.vue'
import BusinessLocationMap from './BusinessLocationMap.vue'
import PurchaseBusinessModal from './PurchaseBusinessModal.vue'
</script>

<template>
    <main class="marketplace-workspace">
        <BusinessLocationList />
        <BusinessLocationMap />
        <BusinessLocationDetails />

        <PurchaseBusinessModal />
    </main>
</template>

<style scoped lang="scss">
.marketplace-workspace {
    display: grid;
    min-width: 0;
    min-height: 0;
    grid-template-columns:
        minmax(18rem, 25%)
        minmax(24rem, 1fr)
        minmax(20rem, 27%);
    gap: var(--space-3);
    padding: var(--space-3);
}
</style>