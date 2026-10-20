<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import RaidCashStacks from './components/RaidCashStacks.vue'
import RaidEvidenceBag from './components/RaidEvidenceBag.vue'
import RaidDeposit from './components/RaidDeposit.vue'
import { useRaidStore } from './stores/raid.store'
import { useRaidDrag } from './composables/useRaidDrag'
import { useRaidFinish } from './composables/useRaidFinish'
import { raidImages } from './utils/raid.utils'
import './styles/raid.scss'

const store = useRaidStore()
const { t, te } = useI18n()
const root = ref<HTMLElement | null>(null)

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

const errorMessage = computed(() => {
    if (!store.error) return ''

    const key = `raid.errors.${store.error}`

    return t(te(key) ? key : 'raid.errors.request_failed')
})
</script>

<template>
    <div class="raid-overlay">
        <section
            ref="root"
            class="raid-scene"
            role="dialog"
            aria-modal="true"
            :aria-label="t('raid.dialogLabel')"
            @pointermove="drag.move"
            @pointerup="drag.up"
            @pointercancel="drag.cancel"
        >
            <img
                class="raid-scene-image"
                :src="raidImages.scene"
                :alt="t('raid.sceneAlt')"
                draggable="false"
            />

            <p v-if="errorMessage" class="raid-error" role="alert">
                {{ errorMessage }}
            </p>

            <RaidCashStacks
                :piles="store.piles"
                :unavailable-ids="unavailableIds"
                :selected-id="selectedPileId"
                :dragging="drag.dragging.value"
                :format="store.format"
                @pick="pickPile"
                @transfer="keyboardPack"
            />

            <RaidEvidenceBag
                :packed-amount="store.displayAmount"
                :dragging="drag.dragging.value"
                :over="drag.over.value"
                :all-packed="store.allPacked"
                :sealed="store.sealed"
                :busy="store.submitting"
                :format="store.format"
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