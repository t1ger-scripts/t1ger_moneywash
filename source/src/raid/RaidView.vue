<script setup lang="ts">
import { ref } from 'vue'
import RaidCashStacks from './components/RaidCashStacks.vue'
import RaidEvidenceBag from './components/RaidEvidenceBag.vue'
import RaidCollection from './components/RaidCollection.vue'
import RaidCompletion from './components/RaidCompletion.vue'
import { useRaidCollect } from './composables/useRaidCollect'
import { useRaidStore } from './stores/raid.store'
import { useRaidDrag } from './composables/useRaidDrag'
import { raidImages } from './utils/raid.utils'
import './styles/raid.scss'

const store = useRaidStore()
const root = ref<HTMLElement | null>(null)

store.reset()

const {
    drag,
    depositing,
    selectedPileId,
    pickPile,
    keyboardPack,
} = useRaidDrag(root)

const {
    collectDrag,
    keyboardCollect,
} = useRaidCollect(root)

</script>

<template>
    <div class="raid-overlay">
        <section
            ref="root"
            class="raid-scene"
            role="dialog"
            aria-modal="true"
            aria-label="Police evidence collection"
            @pointermove="drag.move($event); collectDrag.move($event)"
            @pointerup="drag.up($event); collectDrag.up($event)"
            @pointercancel="drag.cancel(); collectDrag.cancel()"
        >
            <img
                class="raid-scene-image"
                :src="raidImages.scene"
                alt="Open business safe and evidence bag"
                draggable="false"
            />

            <RaidCashStacks
                :piles="store.piles"
                :packed-ids="store.packedIds"
                :selected-id="selectedPileId"
                :dragging="drag.dragging.value"
                @pick="pickPile"
                @transfer="keyboardPack"
            />

            <RaidEvidenceBag
                :packed-ids="store.packedIds"
                :packed-amount="store.packedAmount"
                :pile-count="store.piles.length"
                :dragging="drag.dragging.value && !depositing"
                :over="drag.over.value && !depositing"
                :all-packed="store.allPacked"
                :sealed="store.sealed"
                @seal="store.sealBag"
            />

            <div
                v-if="drag.dragging.value"
                class="raid-cash-bundle raid-cash-ghost"
                data-raid-drag-preview
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

            <RaidCollection
                v-if="store.sealed && !store.collected"
                :amount="store.packedAmount"
                :dragging="collectDrag.dragging.value"
                :over="collectDrag.over.value"
                :x="collectDrag.x.value"
                :y="collectDrag.y.value"
                @pick="collectDrag.down"
                @transfer="keyboardCollect"
            />

            <RaidCompletion
                v-if="store.collected"
                :amount="store.packedAmount"
                @restart="store.reset"
            />
        </section>
    </div>
</template>