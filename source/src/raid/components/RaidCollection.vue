<script setup lang="ts">
import {
    raidImages,
    formatRaidMoney,
} from '../utils/raid.utils'

defineProps<{
    amount: number
    dragging: boolean
    over: boolean
    x: number
    y: number
}>()

const emit = defineEmits<{
    pick: [event: PointerEvent]
    transfer: [event: KeyboardEvent]
}>()
</script>

<template>
    <button
        class="raid-bag-handle"
        data-raid-bag
        aria-label="Collect sealed evidence bag"
        @pointerdown="emit('pick', $event)"
        @keydown.enter.prevent="emit('transfer', $event)"
        @keydown.space.prevent="emit('transfer', $event)"
    >
        <span>DRAG TO COLLECT ↓</span>
    </button>

    <div
        class="raid-collection-target"
        data-raid-collect
        :class="{ 'raid-collection-target--over': over }"
    >
        {{ over ? 'RELEASE TO SECURE' : 'COLLECT EVIDENCE ↓' }}
    </div>

    <div
        v-if="dragging"
        class="raid-bag-ghost"
        :style="{
            left: `${x}px`,
            top: `${y}px`,
            backgroundImage: `url(${raidImages.scene})`,
        }"
        aria-hidden="true"
    >
        <span>
            EVIDENCE SEALED
            <strong>{{ formatRaidMoney(amount) }}</strong>
        </span>
    </div>
</template>