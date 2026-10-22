<script setup lang="ts">
withDefaults(
    defineProps<{
        tone?: 'primary' | 'success'
    }>(),
    {
        tone: 'primary',
    },
)
</script>

<template>
    <span class="app-badge" :class="`app-badge--${tone}`">
        <slot />
    </span>
</template>

<style scoped lang="scss">
.app-badge {
    display: inline-flex;
    flex: 0 0 auto;
    white-space: nowrap;
    min-height: 1.625rem;
    align-items: center;
    padding: 0 var(--space-3);
    border: var(--border-width) solid transparent;
    border-radius: var(--radius-sm);
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-semibold);
    line-height: 1;

    &--primary {
        border-color: var(--color-primary);
        background: var(--color-primary-subtle);
        color: var(--color-primary-hover);
    }

    &--success {
        background: var(--color-success-subtle);
        color: var(--color-success);
    }
}
</style>