<script setup lang="ts">
import { computed, ref } from 'vue'
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

const billFailed = ref(false)

const pileProgress = computed(() =>
    props.collectable
        ? 1
        : Math.max(0, Math.min(1, props.progress)),
)
</script>

<template>
    <div
        class="counter-machine"
        :class="{
            'is-running': running,
            'is-complete': complete,
        }"
        :style="{
            '--bill-duration': `${durationMs / 12}ms`,
            '--pile-progress': pileProgress,
        }"
    >
        <div
            class="counter-feeder"
            :class="{
                'is-over': over,
                'has-cash': running,
            }"
            data-cash-feeder
        >
            <span class="counter-feeder-label">{{ feederLabel }}</span>

            <div
                v-if="running"
                class="counter-input-cash"
                aria-hidden="true"
            >
                <CashStacks compact />
            </div>
        </div>

        <div class="counter-housing">
            <div class="counter-brand">T1GER / CASH COUNTER</div>

            <div class="counter-display">
                <small>{{ displayState }}</small>
                <div>{{ value }}</div>
            </div>

            <div class="counter-keys" aria-hidden="true">
                <span>UV</span>
                <span>MODE</span>
                <span>BATCH</span>
                <span>AUTO</span>
            </div>

            <div class="counter-slot" aria-hidden="true">
                <span
                    class="counter-moving-note"
                    :class="{ 'has-image': !billFailed }"
                >
                    <img
                        v-if="!billFailed"
                        :src="cashCounterImages.bill"
                        alt=""
                        draggable="false"
                        @error="billFailed = true"
                    />
                </span>
            </div>
        </div>

        <button
            v-if="running || collectable"
            type="button"
            class="counter-collected-pile"
            :class="{
                'is-lifted': lifted,
                'is-collectable': collectable,
            }"
            :disabled="!collectable"
            :aria-label="collectLabel"
            :title="collectable ? collectLabel : undefined"
            data-cash-collect
            @pointerdown="emit('collectDown', $event)"
            @pointermove="emit('collectMove', $event)"
            @pointerup="emit('collectUp', $event)"
            @pointercancel="emit('collectCancel')"
            @keydown.enter.prevent="emit('collect')"
            @keydown.space.prevent="emit('collect')"
        >
            <div class="counter-output-cash">
                <CashStacks compact />
            </div>
        </button>
    </div>
</template>