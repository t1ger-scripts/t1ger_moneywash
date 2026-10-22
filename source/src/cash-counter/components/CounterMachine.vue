<script setup lang="ts">
import { computed } from 'vue'
import CashPaper from './CashPaper.vue'
import CashStacks from './CashStacks.vue'
import { cashCounterImages, COUNT_DURATION_MS } from '../utils/cash-counter.utils'

const props = defineProps<{
    value: string
    displayState: string
    feederLabel: string
    running: boolean
    over: boolean
    progress: number
    collectable: boolean
    collectLabel: string
    lifted: boolean
    complete: boolean
}>()

const emit = defineEmits<{
    collectDown: [event: PointerEvent]
    collectMove: [event: PointerEvent]
    collectUp: [event: PointerEvent]
    collectCancel: []
    collect: []
}>()

const clamp = (value: number) => Math.max(0, Math.min(1, value))

/** Notes falling through the machine. Purely visual, they are not currency denominations. */
const NOTE_COUNT = Math.max(12, Math.min(48, Math.round(COUNT_DURATION_MS / 45)))

/** Share of the count one note spends falling; the last note lands exactly at progress 1. */
const TRAVEL = Math.max(0.08, Math.min(0.3, 190 / COUNT_DURATION_MS))

const progress = computed(() =>
    props.collectable ? 1 : clamp(props.progress),
)

const notes = computed(() => {
    const spacing = (1 - TRAVEL) / (NOTE_COUNT - 1)

    return Array.from({ length: NOTE_COUNT }, (_, index) => {
        const raw = (progress.value - index * spacing) / TRAVEL

        return { index, raw, position: clamp(raw) }
    })
})

const movingNotes = computed(() =>
    notes.value.filter((note) => note.raw >= 0 && note.raw < 1),
)

const receivedFill = computed(
    () => notes.value.filter((note) => note.raw >= 1).length / NOTE_COUNT,
)

const inputFill = computed(() => Math.max(0, 1 - progress.value))

const inputStyle = computed(() => ({
    transform: `translateY(${progress.value * 58}%)`,
    opacity: clamp((1 - progress.value) * 12),
}))

/*
 * The received stack starts at 56% of the output path and its top surface
 * rises as it gets thicker. Moving notes land on that surface.
 */
const landingTop = computed(() => 56 + 9.6 * (1 - receivedFill.value))

function noteStyle(index: number, position: number) {
    const eased = 1 - (1 - position) ** 1.6

    const top = -26 + (landingTop.value + 26) * eased

    const flutter =
        Math.sin(position * Math.PI * 4 + index) * Math.sin(position * Math.PI)

    return {
        top: `${top}%`,
        left: `${7.7 + flutter * 0.35}%`,
        zIndex: 20 + index,
        opacity: clamp(position * 9),
        transform: `scaleY(${0.62 + eased * 0.38}) rotate(${flutter * 0.65}deg)`,
        filter: [
            `brightness(${0.78 + eased * 0.14})`,
            `drop-shadow(0 ${1 + (1 - eased) * 3}px 1px #0005)`,
        ].join(' '),
    }
}
</script>

<template>
    <div
        class="counter-machine"
        :class="{
            'is-complete': complete,
        }"
    >
        <div
            class="counter-feeder"
            :class="{ 'is-over': over }"
            data-cash-feeder
            :aria-label="feederLabel"
        >
            <span v-if="!running" class="counter-feeder-label">
                {{ feederLabel }}
            </span>
        </div>

        <div
            v-if="running"
            class="counter-input-window"
            aria-hidden="true"
        >
            <div
                class="counter-input-cash"
                :style="inputStyle"
            >
                <CashPaper :fill="inputFill" />
            </div>
        </div>

        <div
            v-if="running"
            class="counter-paper-path"
            aria-hidden="true"
        >
            <div class="counter-received-cash">
                <CashPaper :fill="receivedFill" />
            </div>

            <img
                v-for="note in movingNotes"
                :key="note.index"
                class="counter-moving-note"
                :src="cashCounterImages.note"
                :style="noteStyle(
                    note.index,
                    note.position
                )"
                alt=""
                draggable="false"
            />
        </div>

        <button
            v-if="collectable"
            class="counter-collected-pile"
            :class="{ 'is-lifted': lifted }"
            type="button"
            data-cash-collect
            :aria-label="collectLabel"
            :title="collectLabel"
            @pointerdown="emit('collectDown', $event)"
            @pointermove="emit('collectMove', $event)"
            @pointerup="emit('collectUp', $event)"
            @pointercancel="emit('collectCancel')"
            @keydown.enter.prevent="emit('collect')"
            @keydown.space.prevent="emit('collect')"
        >
            <CashStacks compact />
        </button>

        <div class="counter-display">
            <strong>{{ value }}</strong>
            <small>{{ displayState }}</small>
        </div>
    </div>
</template>