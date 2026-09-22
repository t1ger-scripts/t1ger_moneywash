<script setup lang="ts">
import BusinessLocationList from './BusinessLocationList.vue'
import BusinessLocationMap from './BusinessLocationMap.vue'
</script>

<template>
    <main class="marketplace-workspace">
        <BusinessLocationList />
        <BusinessLocationMap />
    </main>
</template>

<style scoped lang="scss">
.marketplace-workspace {
    display: grid;
    grid-template-columns: minmax(21rem, 30%) minmax(0, 70%);
    gap: var(--space-4);
    min-height: 0;
    padding: var(--space-4);
    flex: 1;
}

@media (max-width: 80rem) {
    .marketplace-workspace {
        grid-template-columns: minmax(19rem, 34%) minmax(0, 66%);
    }
}
</style>