<script setup lang="ts">

import RaidSeal from './RaidSeal.vue'
import { raidImages, formatRaidMoney } from '../utils/raid.utils'

const emit = defineEmits<{
    seal: []
}>()

defineProps<{
    packedIds: number[]
    packedAmount: number
    pileCount: number
    dragging: boolean
    over: boolean
    allPacked: boolean
    sealed: boolean
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
    <div class="raid-bag-mouth" data-raid-mouth :class="{
        'raid-bag-mouth--active': dragging,
        'raid-bag-mouth--over': over,
    }">
        <svg class="raid-bag-outline" viewBox="0 0 1000 400" preserveAspectRatio="none" aria-hidden="true">
            <path d="
                M 12 135
                C 55 60, 220 5, 390 10
                C 650 5, 890 65, 980 185
                C 1020 255, 830 375, 590 388
                C 350 405, 95 305, 12 170
                Q 2 150, 12 135
                Z
            " vector-effect="non-scaling-stroke" />
        </svg>
        <div class="raid-bag-cash" aria-hidden="true">
            <img v-for="(id, index) in packedIds" :key="id" :src="raidImages.bundle" :style="packedPilePosition(index)"
                alt="" draggable="false" />
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

    <template v-if="allPacked">
        <div class="raid-bag-fold" :style="{
            backgroundImage:
                `linear-gradient(175deg, #a47e4d22, #bc996533), url(${raidImages.scene})`,
        }" aria-hidden="true"></div>

        <RaidSeal :sealed="sealed" @complete="emit('seal')" />
    </template>
</template>