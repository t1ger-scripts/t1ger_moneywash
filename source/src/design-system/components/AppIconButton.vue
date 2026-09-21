<script setup lang="ts">
withDefaults(
    defineProps<{
        label: string
        disabled?: boolean
        variant?: 'surface' | 'ghost'
    }>(),
    {
        disabled: false,
        variant: 'surface',
    },
)
</script>

<template>
    <button class="app-icon-button" :class="`app-icon-button--${variant}`" type="button" :aria-label="label"
        :disabled="disabled">
        <slot />
    </button>
</template>

<style scoped lang="scss">
.app-icon-button {
    display: inline-grid;
    width: 2.75rem;
    height: 2.75rem;
    place-items: center;
    border: var(--border-width) solid transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    transition:
        border-color var(--duration-fast) var(--ease-standard),
        background-color var(--duration-fast) var(--ease-standard),
        color var(--duration-fast) var(--ease-standard);

    &--surface {
        border-color: var(--color-border);
        background: var(--color-surface-raised);
        color: var(--color-text-secondary);
    }

    &--ghost {
        background: transparent;
        color: var(--color-text-secondary);
    }

    &:not(:disabled):hover {
        border-color: var(--color-border);
        background: var(--color-surface-hover);
        color: var(--color-text-primary);
    }

    &:disabled {
        cursor: not-allowed;
        opacity: 0.45;
    }
}
</style>