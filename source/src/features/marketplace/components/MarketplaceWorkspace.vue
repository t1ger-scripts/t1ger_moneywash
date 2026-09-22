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
    min-height: 0;
    grid-template-columns:
        minmax(19rem, 25%) minmax(30rem, 1fr) minmax(22rem, 27%);
    gap: var(--space-3);
    padding: var(--space-3);
}

@media (max-width: 90rem) {
    .marketplace-workspace {
        grid-template-columns:
            minmax(19rem, 29%) minmax(25rem, 1fr) minmax(21rem, 28%);
    }
}
</style>