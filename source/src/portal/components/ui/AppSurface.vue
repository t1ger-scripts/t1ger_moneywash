<script setup lang="ts">
withDefaults(
    defineProps<{
        elevation?: 'base' | 'raised'
    }>(),
    {
        elevation: 'base',
    },
)
</script>

<template>
    <div class="app-surface" :class="`app-surface--${elevation}`">
        <slot />
    </div>
</template>

<style scoped lang="scss">
.app-surface {
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-lg);

    &--base {
        background: var(--color-surface);
    }

    &--raised {
        background: var(--color-surface-raised);
        box-shadow: var(--shadow-surface);
    }
}
</style>