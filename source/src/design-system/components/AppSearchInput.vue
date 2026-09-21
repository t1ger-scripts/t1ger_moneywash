<script setup lang="ts">
import { Search, X } from '@lucide/vue'

const model = defineModel<string>({
    default: '',
})

withDefaults(
    defineProps<{
        label: string
        placeholder?: string
        clearLabel?: string
        disabled?: boolean
    }>(),
    {
        placeholder: '',
        clearLabel: 'Clear search',
        disabled: false,
    },
)
</script>

<template>
    <label class="app-search" :class="{ 'app-search--disabled': disabled }">
        <span class="app-search__label">
            {{ label }}
        </span>

        <Search class="app-search__search-icon" :size="18" aria-hidden="true" />

        <input v-model="model" type="search" :placeholder="placeholder" :disabled="disabled" />

        <button v-if="model && !disabled" type="button" :aria-label="clearLabel" :title="clearLabel"
            @click="model = ''">
            <X :size="16" aria-hidden="true" />
        </button>
    </label>
</template>

<style scoped lang="scss">
.app-search {
    position: relative;
    display: flex;
    min-height: 2.75rem;
    align-items: center;
    gap: var(--space-3);
    padding: 0 var(--space-4);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--color-background);
    color: var(--color-text-muted);
    transition:
        border-color var(--duration-fast) var(--ease-standard),
        box-shadow var(--duration-fast) var(--ease-standard);

    &:focus-within {
        border-color: var(--color-primary);
        box-shadow: var(--focus-ring);
    }

    &--disabled {
        cursor: not-allowed;
        opacity: 0.5;
    }

    &__label {
        position: absolute;
        width: 1px;
        height: 1px;
        overflow: hidden;
        clip: rect(0 0 0 0);
        clip-path: inset(50%);
        white-space: nowrap;
    }

    &__search-icon {
        flex: 0 0 auto;
    }

    input {
        min-width: 0;
        flex: 1;
        border: 0;
        outline: none;
        background: transparent;
        color: var(--color-text-primary);

        &::placeholder {
            color: var(--color-text-muted);
        }

        &::-webkit-search-cancel-button {
            display: none;
        }
    }

    button {
        display: grid;
        flex: 0 0 auto;
        padding: var(--space-1);
        place-items: center;
        background: transparent;
        color: var(--color-text-muted);
        cursor: pointer;

        &:hover {
            color: var(--color-text-primary);
        }
    }
}
</style>