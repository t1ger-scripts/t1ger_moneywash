<script setup lang="ts">
import {
    onBeforeUnmount,
    useId,
    watch,
} from 'vue'

import { X } from '@lucide/vue'

import AppIconButton from './AppIconButton.vue'

const props = withDefaults(
    defineProps<{
        open: boolean
        title: string
        eyebrow?: string
        closeLabel?: string
    }>(),
    {
        eyebrow: '',
        closeLabel: 'Close',
    },
)

const emit = defineEmits<{
    close: []
}>()

const titleId = useId()

function closeModal(): void {
    emit('close')
}

function handleKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape' && props.open) {
        closeModal()
    }
}

watch(
    () => props.open,
    (isOpen) => {
        if (isOpen) {
            document.addEventListener('keydown', handleKeydown)
            return
        }

        document.removeEventListener('keydown', handleKeydown)
    },
)

onBeforeUnmount(() => {
    document.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
    <Teleport to="body">
        <Transition name="app-modal">
            <div v-if="open" class="app-modal" role="presentation" @click.self="closeModal">
                <section class="app-modal__dialog" role="dialog" aria-modal="true" :aria-labelledby="titleId">
                    <header class="app-modal__header">
                        <div class="app-modal__heading">
                            <span v-if="eyebrow" class="app-modal__eyebrow">
                                {{ eyebrow }}
                            </span>

                            <h2 :id="titleId">
                                {{ title }}
                            </h2>
                        </div>

                        <AppIconButton :label="closeLabel" @click="closeModal">
                            <X :size="20" aria-hidden="true" />
                        </AppIconButton>
                    </header>

                    <div class="app-modal__content">
                        <slot />
                    </div>

                    <footer v-if="$slots.footer" class="app-modal__footer">
                        <slot name="footer" />
                    </footer>
                </section>
            </div>
        </Transition>
    </Teleport>
</template>

<style scoped lang="scss">
.app-modal {
    position: fixed;
    z-index: var(--z-index-overlay);
    inset: 0;
    display: grid;
    padding: var(--space-6);
    place-items: center;
    background: var(--color-overlay);

    &__dialog {
        width: min(36rem, 100%);
        max-height: calc(100vh - (var(--space-6) * 2));
        overflow: hidden auto;
        border: var(--border-width) solid var(--color-border-strong);
        border-radius: var(--radius-xl);
        background: var(--color-surface);
        box-shadow: var(--shadow-modal);
    }

    &__header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: var(--space-4);
        padding: var(--space-6);
        border-bottom: var(--border-width) solid var(--color-border);
    }

    &__heading {
        min-width: 0;
    }

    &__eyebrow {
        display: block;
        margin-bottom: var(--space-2);
        color: var(--color-primary-hover);
        font-size: var(--font-size-xs);
        font-weight: var(--font-weight-semibold);
        letter-spacing: var(--letter-spacing-label);
        text-transform: uppercase;
    }

    &__content {
        padding: var(--space-6);
    }

    &__footer {
        display: flex;
        justify-content: flex-end;
        gap: var(--space-3);
        padding: var(--space-5) var(--space-6);
        border-top: var(--border-width) solid var(--color-border);
    }
}

.app-modal-enter-active,
.app-modal-leave-active {
    transition:
        opacity var(--duration-normal) var(--ease-standard);
}

.app-modal-enter-active .app-modal__dialog,
.app-modal-leave-active .app-modal__dialog {
    transition:
        transform var(--duration-normal) var(--ease-standard);
}

.app-modal-enter-from,
.app-modal-leave-to {
    opacity: 0;
}

.app-modal-enter-from .app-modal__dialog,
.app-modal-leave-to .app-modal__dialog {
    transform: translateY(0.75rem) scale(0.98);
}
</style>