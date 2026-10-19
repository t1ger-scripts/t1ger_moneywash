<script setup lang="ts">
import { useRaidSeal } from '../composables/useRaidSeal'

const props = defineProps<{
    sealed: boolean
}>()

const emit = defineEmits<{
    complete: []
}>()

const {
    progress,
    down,
    move,
    up,
    cancel,
    finish,
} = useRaidSeal(
    () => !props.sealed,
    () => emit('complete'),
)
</script>

<template>
    <button
        class="raid-seal"
        :class="{ 'raid-seal--complete': sealed }"
        :style="{
            '--seal-progress': sealed
                ? '100%'
                : `${progress * 100}%`,
        }"
        :disabled="sealed"
        aria-label="Slide from left to right to secure the evidence. Alternatively, press Enter."
        @pointerdown="down"
        @pointermove="move"
        @pointerup="up"
        @pointercancel="cancel"
        @keydown.enter.prevent="finish"
        @keydown.space.prevent="finish"
    >
        <span class="raid-seal-text">
            {{
                sealed
                    ? 'EVIDENCE SECURED'
                    : 'EVIDENCE · SLIDE TO SECURE'
            }}
        </span>

        <span
            v-if="!sealed"
            class="raid-seal-handle"
            :style="{ left: `${6 + progress * 88}%` }"
            aria-hidden="true"
        >
            →
        </span>
    </button>
</template>