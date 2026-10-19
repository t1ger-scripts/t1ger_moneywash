<script setup lang="ts">
import {
    raidImages,
    formatRaidMoney,
} from '../utils/raid.utils'

defineProps<{
    packedIds: number[]
    packedAmount: number
    pileCount: number
    dragging: boolean
    over: boolean
}>()

function packedPilePosition(index: number) {
    return {
        left: `${10 + (index % 3) * 21}%`,
        bottom: `${Math.floor(index / 3) * 12 - 4}%`,
        transform: `rotate(${index % 2 ? 7 : -7}deg)`,
    }
}
</script>

<template>
    <div
        class="raid-bag-mouth"
        data-raid-mouth
        :class="{
            'raid-bag-mouth--active': dragging,
            'raid-bag-mouth--over': over,
        }"
    >
        <div class="raid-bag-cash" aria-hidden="true">
            <img
                v-for="(id, index) in packedIds"
                :key="id"
                :src="raidImages.bundle"
                :style="packedPilePosition(index)"
                alt=""
                draggable="false"
            />
        </div>

        <span v-if="dragging" class="raid-bag-hint">
            {{ over ? 'RELEASE TO BAG' : 'DROP CASH HERE' }}
        </span>
    </div>

    <div class="raid-evidence-label" aria-live="polite">
        <span>POLICE EVIDENCE</span>

        <strong>{{ formatRaidMoney(packedAmount) }}</strong>

        <small>
            {{ packedIds.length }} / {{ pileCount }} bundles secured
        </small>
    </div>
</template>