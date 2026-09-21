<script setup lang="ts">
withDefaults(
    defineProps<{
        tone?: 'neutral' | 'primary' | 'success' | 'warning' | 'danger'
    }>(),
    {
        tone: 'neutral',
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
    min-height: 1.625rem;
    align-items: center;
    justify-content: center;
    padding: 0 var(--space-3);
    border: var(--border-width) solid transparent;
    border-radius: var(--radius-pill);
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-semibold);
    line-height: 1;

    &--neutral {
        border-color: var(--color-border);
        background: var(--color-surface-raised);
        color: var(--color-text-secondary);
    }

    &--primary {
        border-color: var(--color-primary);
        background: var(--color-primary-subtle);
        color: var(--color-primary-hover);
    }

    &--success {
        background: var(--color-success-subtle);
        color: var(--color-success);
    }

    &--warning {
        background: var(--color-warning-subtle);
        color: var(--color-warning);
    }

    &--danger {
        background: var(--color-danger-subtle);
        color: var(--color-danger);
    }
}
</style>