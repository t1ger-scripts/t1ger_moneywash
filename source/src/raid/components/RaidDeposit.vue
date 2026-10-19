<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { raidImages } from '../utils/raid.utils'
import type { RaidDeposit } from '../raid.types'

const props = defineProps<{
    deposit: RaidDeposit
}>()

const emit = defineEmits<{
    complete: [id: number]
}>()

const element = ref<HTMLElement | null>(null)

let animation: Animation | null = null
let disposed = false

onMounted(async () => {
    const reducedMotion = window.matchMedia(
        '(prefers-reduced-motion: reduce)',
    ).matches

    try {
        if (element.value) {
            animation = element.value.animate(
                [
                    {
                        transform:
                            'translate(-50%, -50%) rotate(-2deg) scale(1)',
                        opacity: 1,
                    },
                    {
                        offset: 0.4,
                        opacity: 0.8,
                    },
                    {
                        transform:
                            'translate(-50%, 70%) rotate(5deg) scale(0.85)',
                        opacity: 0,
                    },
                ],
                {
                    duration: reducedMotion ? 0 : 450,
                    easing: 'cubic-bezier(0.4, 0, 0.8, 1)',
                    fill: 'forwards',
                },
            )

            await animation.finished
        }
    } catch {
        // An interrupted animation must not leave a deposit stuck.
    }

    if (!disposed) {
        emit('complete', props.deposit.id)
    }
})

onBeforeUnmount(() => {
    disposed = true
    animation?.cancel()
})
</script>

<template>
    <div
        ref="element"
        class="raid-cash-bundle raid-cash-ghost"
        :style="{
            left: `${deposit.x}%`,
            top: `${deposit.y}%`,
            zIndex: 40,
        }"
        aria-hidden="true"
    >
        <span class="raid-cash-art">
            <img
                :src="raidImages.bundle"
                alt=""
                draggable="false"
            />
        </span>
    </div>
</template>