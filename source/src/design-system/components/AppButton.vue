<script setup lang="ts">
withDefaults(
    defineProps<{
        variant?: 'primary' | 'secondary' | 'ghost' | 'danger'
        size?: 'small' | 'medium' | 'large'
        type?: 'button' | 'submit' | 'reset'
        disabled?: boolean
        loading?: boolean
        block?: boolean
    }>(),
    {
        variant: 'primary',
        size: 'medium',
        type: 'button',
        disabled: false,
        loading: false,
        block: false,
    },
)
</script>

<template>
    <button class="app-button" :class="[
        `app-button--${variant}`,
        `app-button--${size}`,
        {
            'app-button--block': block,
        },
    ]" :type="type" :disabled="disabled || loading" :aria-busy="loading">
        <span v-if="loading" class="app-button__spinner" aria-hidden="true" />

        <slot />
    </button>
</template>

<style scoped lang="scss">
.app-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    border: var(--border-width) solid transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: var(--font-weight-semibold);
    line-height: 1;
    transition:
        background-color var(--duration-fast) var(--ease-standard),
        border-color var(--duration-fast) var(--ease-standard),
        color var(--duration-fast) var(--ease-standard),
        opacity var(--duration-fast) var(--ease-standard);

    &:disabled {
        cursor: not-allowed;
        opacity: 0.5;
    }

    &--small {
        min-height: 2.25rem;
        padding: 0 var(--space-3);
        font-size: var(--font-size-sm);
    }

    &--medium {
        min-height: 2.75rem;
        padding: 0 var(--space-5);
        font-size: var(--font-size-sm);
    }

    &--large {
        min-height: 3.25rem;
        padding: 0 var(--space-6);
        font-size: var(--font-size-md);
    }

    &--primary {
        background: var(--color-primary);
        color: var(--color-text-inverse);

        &:not(:disabled):hover {
            background: var(--color-primary-hover);
        }

        &:not(:disabled):active {
            background: var(--color-primary-active);
        }
    }

    &--secondary {
        border-color: var(--color-border-strong);
        background: var(--color-surface-raised);
        color: var(--color-text-primary);

        &:not(:disabled):hover {
            background: var(--color-surface-hover);
        }
    }

    &--ghost {
        background: transparent;
        color: var(--color-text-secondary);

        &:not(:disabled):hover {
            background: var(--color-surface-hover);
            color: var(--color-text-primary);
        }
    }

    &--danger {
        background: var(--color-danger);
        color: var(--color-text-inverse);
    }

    &--block {
        width: 100%;
    }

    &__spinner {
        width: 1rem;
        height: 1rem;
        border: 2px solid currentColor;
        border-right-color: transparent;
        border-radius: 50%;
        animation: app-button-spin 700ms linear infinite;
    }
}

@keyframes app-button-spin {
    to {
        transform: rotate(360deg);
    }
}
</style>