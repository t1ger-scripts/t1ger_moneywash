<script setup lang="ts">
import { ref } from 'vue'
import RaidCashStacks from './components/RaidCashStacks.vue'
import RaidEvidenceBag from './components/RaidEvidenceBag.vue'
import RaidDeposit from './components/RaidDeposit.vue'
import { useRaidStore } from './stores/raid.store'
import { useRaidDrag } from './composables/useRaidDrag'
import { useRaidFinish } from './composables/useRaidFinish'
import { raidImages } from './utils/raid.utils'
import './styles/raid.scss'

const store = useRaidStore()
const root = ref<HTMLElement | null>(null)

store.reset()

const {
    drag,
    deposits,
    unavailableIds,
    selectedPileId,
    pickPile,
    keyboardPack,
    finishDeposit,
} = useRaidDrag(root)

useRaidFinish()
</script>

<template>
    <div class="raid-overlay">
        <section
            ref="root"
            class="raid-scene"
            role="dialog"
            aria-modal="true"
            aria-label="Police evidence collection"
            @pointermove="drag.move"
            @pointerup="drag.up"
            @pointercancel="drag.cancel"
        >
            <img
                class="raid-scene-image"
                :src="raidImages.scene"
                alt="Open business safe and evidence bag"
                draggable="false"
            />

            <RaidCashStacks
                :piles="store.piles"
                :packed-ids="unavailableIds"
                :selected-id="selectedPileId"
                :dragging="drag.dragging.value"
                @pick="pickPile"
                @transfer="keyboardPack"
            />

            <RaidEvidenceBag
                :packed-ids="store.packedIds"
                :packed-amount="store.packedAmount"
                :pile-count="store.piles.length"
                :dragging="drag.dragging.value"
                :over="drag.over.value"
                :all-packed="store.allPacked"
                :sealed="store.sealed"
                @seal="store.sealBag"
            />

            <RaidDeposit
                v-for="deposit in deposits"
                :key="deposit.id"
                :deposit="deposit"
                @complete="finishDeposit"
            />

            <div
                v-if="drag.dragging.value"
                class="raid-cash-bundle raid-cash-ghost"
                :style="{
                    left: `${drag.x.value}px`,
                    top: `${drag.y.value}px`,
                }"
                aria-hidden="true"
            >
                <span class="raid-cash-art">
                    <img
                        :src="raidImages.bundle"
                        alt=""
                        draggable="false"
                    />
                </span>
            </div>
        </section>
    </div>
</template>