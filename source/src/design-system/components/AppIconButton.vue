<script setup lang="ts">
withDefaults(
    defineProps<{
        label: string
        disabled?: boolean
    }>(),
    {
        disabled: false,
    },
)
</script>

<template>
    <button class="app-icon-button" type="button" :aria-label="label" :title="label" :disabled="disabled">
        <slot />
    </button>
</template>

<style scoped lang="scss">
.app-icon-button {
    display: inline-grid;
    width: 2.75rem;
    height: 2.75rem;
    place-items: center;
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--color-surface-raised);
    color: var(--color-text-secondary);
    cursor: pointer;
    transition:
        background-color var(--duration-fast) var(--ease-standard),
        border-color var(--duration-fast) var(--ease-standard),
        color var(--duration-fast) var(--ease-standard);

    &:not(:disabled):hover {
        border-color: var(--color-border-strong);
        background: var(--color-surface-hover);
        color: var(--color-text-primary);
    }

    &:disabled {
        cursor: not-allowed;
        opacity: 0.45;
    }
}
</style>