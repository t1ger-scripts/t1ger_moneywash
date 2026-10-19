<script setup lang="ts">
import {
    raidImages,
    safePilePosition,
    formatRaidMoney,
} from '../utils/raid.utils'

defineProps<{
    piles: number[]
    packedIds: number[]
    selectedId: number | null
    dragging: boolean
}>()

const emit = defineEmits<{
    pick: [event: PointerEvent, id: number]
    transfer: [event: KeyboardEvent, id: number]
}>()
</script>

<template>
    <div class="raid-cash-stacks">
        <template v-for="(amount, id) in piles" :key="id">
            <button
                v-if="!packedIds.includes(id)"
                class="raid-cash-bundle"
                data-raid-cash
                :style="safePilePosition(id, piles.length)"
                :class="{
                    'raid-cash-bundle--held':
                        dragging && selectedId === id,
                }"
                :aria-label="`Bag ${formatRaidMoney(amount)}`"
                @pointerdown="emit('pick', $event, id)"
                @keydown.enter.prevent="emit('transfer', $event, id)"
                @keydown.space.prevent="emit('transfer', $event, id)"
            >
                <img
                    :src="raidImages.bundle"
                    alt=""
                    draggable="false"
                />

                <span class="raid-cash-amount">
                    {{ formatRaidMoney(amount) }}
                </span>
            </button>
        </template>
    </div>
</template>