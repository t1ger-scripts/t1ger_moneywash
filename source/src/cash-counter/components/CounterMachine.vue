<script setup lang="ts">
import { computed } from 'vue'
import CashStacks from './CashStacks.vue'
import { cashCounterImages } from '../utils/cash-counter.utils'

const props = defineProps<{
    value: string
    displayState: string
    feederLabel: string
    running: boolean
    over: boolean
    durationMs: number
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

const NOTE_COUNT = 20
const TRAVEL = 0.24
const SPACING = (1 - TRAVEL) / (NOTE_COUNT - 1)

const clamp = (value: number) => Math.max(0, Math.min(1, value))

const progress = computed(() =>
    props.collectable ? 1 : clamp(props.progress),
)

const notes = computed(() =>
    Array.from({ length: NOTE_COUNT }, (_, index) => {
        const raw = (progress.value - index * SPACING) / TRAVEL
        const position = clamp(raw)

        return {
            index,
            entering: raw > 0 && position < 0.32,
            exiting: position > 0.65 && raw < 1,
            landed: raw >= 1,
            entry: clamp(position / 0.32),
            exit: clamp((position - 0.65) / 0.35),
        }
    }),
)

const outgoing = computed(() =>
    notes.value.filter((note) => note.exiting),
)

const outputProgress = computed(() =>
    notes.value.filter((note) => note.landed).length / NOTE_COUNT,
)

const inputStyle = computed(() => ({
    transform: `translateY(${progress.value * 85}%)`,
    opacity: progress.value >= 0.995 ? 0 : 1,
}))

const outputStyle = computed(() => ({
    transform: `translateY(${(1 - outputProgress.value) * 38}%)`,
    opacity: outputProgress.value > 0 ? 1 : 0,
}))

function outgoingStyle(index: number, exit: number) {
    return {
        transform: [
            `translateY(${exit * 55}%)`,
            `rotateX(${55 - exit * 20}deg)`,
            `rotateZ(${(index % 2 ? 1 : -1) * 0.8}deg)`,
        ].join(' '),
        opacity: Math.min(1, exit * 7),
    }
}
</script>

<template>
    <div
        class="counter-machine"
        :class="{
            'is-running': running,
            'is-complete': complete,
        }"
        :style="{
            '--roller-time': `${Math.max(45, durationMs / NOTE_COUNT)}ms`,
        }"
    >
        <img
            class="machine-art"
            :src="cashCounterImages.machine"
            alt=""
            draggable="false"
        />

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

        <div v-if="running" class="machine-input-window">
            <img
                class="machine-input-stack"
                :src="cashCounterImages.loose"
                :style="inputStyle"
                alt=""
                draggable="false"
            />
        </div>

        <div class="machine-output-window" aria-hidden="true">
            <img
                v-for="note in outgoing"
                v-show="running"
                :key="`out-${note.index}`"
                class="machine-output-note"
                :src="cashCounterImages.bill"
                :style="outgoingStyle(note.index, note.exit)"
                alt=""
                draggable="false"
            />

            <img
                v-if="running"
                class="machine-output-stack"
                :src="cashCounterImages.loose"
                :style="outputStyle"
                alt=""
                draggable="false"
            />
        </div>

        <div
            v-if="running"
            class="machine-roller-motion"
            aria-hidden="true"
        />

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

        <!--
            These are clipped copies of the SAME machine image.
            They put the actual guides and front lip in front of the cash.
        -->
        <img
            class="machine-art machine-art--input-front"
            :src="cashCounterImages.machine"
            alt=""
            draggable="false"
        />

        <img
            class="machine-art machine-art--output-front"
            :src="cashCounterImages.machine"
            alt=""
            draggable="false"
        />

        <div class="counter-display">
            <strong>{{ value }}</strong>
            <small>{{ displayState }}</small>
        </div>
    </div>
</template>