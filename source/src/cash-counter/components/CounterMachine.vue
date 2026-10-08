<script setup lang="ts">
import { ref } from 'vue'
import CashStacks from './CashStacks.vue'
import { cashCounterImages } from '../utils/cash-counter.utils'

defineProps<{
    value: string
    displayState: string
    feederLabel: string
    running: boolean
    over: boolean
    durationMs: number
    collectable: boolean
    collectLabel: string
    lifted: boolean
}>()

const emit = defineEmits<{
    collectDown: [event: PointerEvent]
    collectMove: [event: PointerEvent]
    collectUp: [event: PointerEvent]
    collectCancel: []
    collect: []
}>()

const billFailed = ref(false)
</script>

<template>
    <div
        class="counter-machine"
        :class="{ 'is-running': running }"
        :style="{ '--bill-duration': `${durationMs / 12}ms` }"
    >
        <div
            class="counter-feeder"
            :class="{ 'is-over': over }"
            data-cash-feeder
        >
            {{ feederLabel }}
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
            v-if="collectable"
            type="button"
            class="counter-collected-pile"
            :class="{ 'is-lifted': lifted }"
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
    </div>
</template>