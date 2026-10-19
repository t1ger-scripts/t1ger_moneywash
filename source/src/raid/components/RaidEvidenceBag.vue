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

</script>

<template>
    <div class="raid-bag-mouth" data-raid-mouth :class="{
        'raid-bag-mouth--active': dragging,
        'raid-bag-mouth--over': over,
    }">
        <svg class="raid-bag-outline" viewBox="0 0 1000 400" preserveAspectRatio="none" aria-hidden="true">
            <path
                data-raid-drop-shape
                d="
                    M 14 140
                    C 55 60, 220 5, 390 10
                    C 650 5, 890 65, 978 185
                    C 1005 225, 830 310, 590 318
                    C 350 330, 95 263, 14 172
                    Q 4 150, 14 140
                    Z
                "
                vector-effect="non-scaling-stroke"
            />
        </svg>

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