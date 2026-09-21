<script setup lang="ts">
import AppBadge from '@/design-system/components/AppBadge.vue'
import AppSurface from '@/design-system/components/AppSurface.vue'
</script>

<template>
    <main class="marketplace-view">
        <AppSurface class="marketplace-view__foundation">
            <AppBadge tone="primary">
                Portal connected
            </AppBadge>

            <h1>Los Santos Business Portal</h1>

            <p>
                The marketplace workspace is ready to be assembled.
            </p>
        </AppSurface>
    </main>
</template>

<style scoped lang="scss">
.marketplace-view {
    display: grid;
    width: 100%;
    height: 100%;
    padding: var(--space-6);
    place-items: center;

    &__foundation {
        width: min(42rem, 100%);
        padding: var(--space-8);
        text-align: center;
    }

    h1 {
        margin-top: var(--space-4);
    }

    p {
        margin-top: var(--space-2);
        color: var(--color-text-secondary);
    }
}
</style>