<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import CashPaper from './components/CashPaper.vue'
import CashStacks from './components/CashStacks.vue'
import CounterMachine from './components/CounterMachine.vue'
import { useCounterSound } from './composables/useCounterSound'
import { useCashCounterStore } from './stores/cash-counter.store'
import {
    cashCounterImages,
    cashPileGeometry,
    COUNT_DURATION_MS,
    trayPilePosition,
} from './utils/cash-counter.utils'
import { useSceneDrag } from '@/shared/composables/useSceneDrag'
import type { CashPile } from './cash-counter.types'
import './styles/cash-counter.scss'
import './styles/cash-counter-scene.scss'
import './styles/cash-counter-paper.scss'

const store = useCashCounterStore()
const sound = useCounterSound()
const { t } = useI18n()

const root = ref<HTMLElement | null>(null)

/** Scene layers drawn on top of the cash, so the trays and machine cover it. */
const foregroundParts = ['left-tray', 'right-tray', 'input', 'output'] as const

const selectedPileId = ref<number | null>(null)
const finalPileHovered = ref(false)

const format = (amount: number) =>
    `${store.payload?.currency ?? '$'}${Math.floor(
        Math.max(0, amount),
    ).toLocaleString(store.payload?.locale ?? 'en')}`

// Piles

/** Piles still waiting on the left tray. */
const leftPiles = computed<CashPile[]>(() =>
    store.piles
        .map((amount, id) => ({ id, amount }))
        .filter(({ id }) =>
            !store.completedPileIds.includes(id) && store.activePileId !== id,
        )
        .map((pile, slot) => ({ ...pile, slot })),
)

/** Counted piles on the right tray. */
const rightPiles = computed<CashPile[]>(() =>
    store.completedPileIds.map((id, slot) => ({
        id,
        amount: store.piles[id] ?? 0,
        slot,
    })),
)

/** Where a pile dropped on the right tray lands. */
const landingStyle = computed(() =>
    trayPilePosition(store.collected, store.collected + 1),
)

// Dragging: left pile into the machine, counted pile to the right tray, final pile to the drop zone

function loadPile() {
    const id = selectedPileId.value
    if (id === null) return

    sound.prime()
    store.loadPile(id)

    if (store.running) sound.loaded()
}

function collectPile() {
    sound.prime()
    store.collectPile()
}

const feedDrag = useSceneDrag(root, () => store.canLoad, loadPile)

const collectDrag = useSceneDrag(
    root,
    () => store.canCollect,
    collectPile,
    '[data-cash-output]',
)

const finalDrag = useSceneDrag(
    root,
    () => store.canFinish && !feedDrag.dragging.value && !collectDrag.dragging.value,
    () => store.complete(),
    '[data-cash-finish]',
    '[data-cash-final-pile]',
)

const anyDrag = () =>
    feedDrag.dragging.value || collectDrag.dragging.value || finalDrag.dragging.value

function cancelDrags() {
    feedDrag.cancel()
    collectDrag.cancel()
    finalDrag.cancel()
}

/** The pile under the cursor while dragging. */
const activeDrag = computed(() =>
    collectDrag.dragging.value ? collectDrag : feedDrag,
)

const dragAmount = computed(() => {
    if (collectDrag.dragging.value) return store.activeAmount

    const id = selectedPileId.value
    return id === null ? 0 : store.piles[id] ?? 0
})

function pickPile(event: PointerEvent, id: number) {
    if (!store.canLoad || anyDrag()) return

    selectedPileId.value = id
    sound.prime()
    feedDrag.down(event)
}

function pickCollected(event: PointerEvent) {
    sound.prime()
    collectDrag.down(event)
}

function pickFinalPile(event: PointerEvent) {
    sound.prime()
    finalDrag.down(event)
}

// Keyboard: the same moves without dragging

function keyboardLoad(id: number) {
    sound.prime()

    if (!store.canLoad || anyDrag()) return

    selectedPileId.value = id

    const pile = root.value?.querySelector<HTMLElement>(
        `.counter-pile [data-pile-id="${id}"]`,
    )

    if (pile) void feedDrag.transfer(pile)
}

function keyboardCollect() {
    sound.prime()

    if (anyDrag()) return

    const pile = root.value?.querySelector<HTMLElement>('[data-cash-collect]')

    if (pile) void collectDrag.transfer(pile)
}

function keyboardFinish() {
    const pile = root.value?.querySelector<HTMLElement>('[data-cash-final-pile]')

    if (!pile) return

    sound.prime()
    void finalDrag.transfer(pile)
}

// Final pile

const finalPileGeometry = computed(() =>
    cashPileGeometry(rightPiles.value.length),
)

const finalPileStyle = computed(() => ({
    height: `${finalPileGeometry.value.height}%`,
}))

const finalGhostStyle = computed(() => ({
    left: `${finalDrag.x.value}px`,
    top: `${finalDrag.y.value}px`,

    // The tray's cash region is 37.23% of the scene height.
    height: `${finalPileGeometry.value.height * 0.3723}%`,
}))

function finalBundleStyle(slot: number) {
    const { rise, height } = finalPileGeometry.value

    return {
        bottom: `${slot * rise / height * 100}%`,
        height: `${27.85 / height * 100}%`,
        zIndex: slot + 1,
    }
}

// Texts

const finalHint = computed(() => {
    if (store.finished) return t('cashCounter.complete')
    if (finalDrag.over.value) return t('cashCounter.releaseToFinish')

    return t(
        finalDrag.dragging.value
            ? 'cashCounter.putCashAway'
            : 'cashCounter.dragToFinish',
    )
})

/** Read out by screen readers. */
const status = computed(() => {
    if (store.finished) return t('cashCounter.complete')

    if (store.running) {
        return t('cashCounter.countingPile', {
            current: store.collected + 1,
            total: store.piles.length,
        })
    }

    if (store.canCollect) return t('cashCounter.collectReady')
    if (store.allCollected) return t('cashCounter.dragToFinish')

    return t('cashCounter.ready')
})

const feederLabel = computed(() => {
    if (feedDrag.over.value) return t('cashCounter.releasePile')
    if (store.finished) return t('cashCounter.complete')
    if (store.running) return t('cashCounter.counting')
    if (store.canCollect) return t('cashCounter.collectReady')
    if (store.allCollected) return t('cashCounter.batchComplete')

    return t(
        store.collected > 0
            ? 'cashCounter.nextPile'
            : 'cashCounter.dropHere',
    )
})

const displayState = computed(() => {
    if (store.finished) return t('cashCounter.complete')
    if (store.running) return t('cashCounter.counting')
    if (store.canCollect) return t('cashCounter.collectReady')
    if (store.allCollected) return t('cashCounter.batchComplete')

    return t('cashCounter.awaiting')
})

// Sounds and automatic steps

watch(() => store.running, (running) => {
    if (running) sound.start()
    else sound.stop()
})

watch(() => store.phase, async (phase, previous) => {
    if (previous === 'counting' && phase !== 'counting') {
        sound.counted()
    }

    if (phase !== 'collect' || !store.settings.autoMoveToRight) return

    const session = store.payload

    await nextTick()

    // Skip if the counter was closed or the pile was already moved meanwhile.
    if (session !== store.payload || !store.canCollect || collectDrag.dragging.value) return

    keyboardCollect()
})

watch(() => store.collected, (count, previous) => {
    if (count > previous && !store.finished) sound.placed()
})

let closeTimer = 0

watch(() => store.finished, (finished) => {
    clearTimeout(closeTimer)

    if (!finished) return

    sound.deposited()
    cancelDrags()

    const session = store.payload

    // Short pause so the player sees "Complete" before the screen closes.
    closeTimer = window.setTimeout(() => {
        if (store.payload === session && store.finished) {
            void store.close()
        }
    }, 400)
})

// Lifecycle

let animation = 0

function frame() {
    store.tick(performance.now())

    if (store.running) sound.feed(COUNT_DURATION_MS / 12)

    animation = requestAnimationFrame(frame)
}

/** ESC while dragging drops the pile; otherwise ESC closes the counter (useUiLifecycle). */
function escape(event: KeyboardEvent) {
    if (event.key !== 'Escape' || !anyDrag()) return

    event.preventDefault()
    cancelDrags()
}

onMounted(() => {
    frame()
    document.addEventListener('keydown', escape)
})

onUnmounted(() => {
    cancelAnimationFrame(animation)
    clearTimeout(closeTimer)
    cancelDrags()
    sound.dispose()
    document.removeEventListener('keydown', escape)
})
</script>

<template>
    <div class="cash-counter-overlay cash-counter-overlay--scene">
        <section
            ref="root"
            class="cash-counter cash-counter--scene"
            role="dialog"
            aria-modal="true"
            aria-labelledby="cash-counter-title"
        >
            <img class="counter-scene-image" :src="cashCounterImages.scene" alt="" draggable="false" />

            <h1 id="cash-counter-title" class="counter-sr-only">
                {{ t('cashCounter.title') }}
            </h1>

            <span class="counter-sr-only" role="status">{{ status }}</span>

            <button class="counter-scene-close" type="button" :aria-label="t('common.close')" @click="store.close">
                <kbd>ESC</kbd>
                <span>{{ t('common.close') }}</span>
            </button>

            <div class="counter-desk">
                <div class="counter-source">
                    <div class="counter-cash-tray">
                        <div class="counter-pile">
                            <CashStacks
                                :items="leftPiles"
                                :banded="false"
                                :total-slots="leftPiles.length"
                                :format="format"
                                interactive
                                :disabled="!store.canLoad"
                                :lifted-id="feedDrag.dragging.value ? selectedPileId : null"
                                @pick="pickPile"
                                @move="feedDrag.move"
                                @release="feedDrag.up"
                                @cancel="feedDrag.cancel"
                                @load="keyboardLoad"
                            />
                        </div>
                    </div>
                </div>

                <CounterMachine
                    :value="format(store.countedAmount)"
                    :display-state="displayState"
                    :feeder-label="feederLabel"
                    :running="store.running"
                    :over="feedDrag.over.value"
                    :progress="store.progress"
                    :collectable="store.canCollect"
                    :collect-label="t('cashCounter.collectPile', { amount: format(store.activeAmount) })"
                    :lifted="collectDrag.dragging.value"
                    :complete="store.finished"
                    @collect-down="pickCollected"
                    @collect-move="collectDrag.move"
                    @collect-up="collectDrag.up"
                    @collect-cancel="collectDrag.cancel"
                    @collect="keyboardCollect"
                />

                <div
                    class="counter-output"
                    :class="{
                        'is-target': collectDrag.dragging.value,
                        'is-over': collectDrag.over.value,
                        'is-final-lifted': finalDrag.dragging.value || store.finished,
                        'is-final-hovered': finalPileHovered && store.canFinish && !finalDrag.dragging.value,
                    }"
                >
                    <div class="counter-tray" data-cash-output>
                        <CashStacks :items="rightPiles" :total-slots="rightPiles.length" :format="format" />

                        <span class="cash-stacks counter-stack-target" aria-hidden="true">
                            <span data-cash-landing :style="landingStyle" />
                        </span>

                        <div v-if="store.allCollected" class="counter-final-pile-region">
                            <button
                                class="counter-final-pile"
                                type="button"
                                data-cash-final-pile
                                :style="finalPileStyle"
                                :disabled="!store.canFinish"
                                :aria-label="t('cashCounter.dragToFinish')"
                                @pointerdown="pickFinalPile"
                                @pointermove="finalDrag.move"
                                @pointerup="finalDrag.up"
                                @pointerenter="finalPileHovered = true"
                                @pointerleave="finalPileHovered = false"
                                @focus="finalPileHovered = true"
                                @blur="finalPileHovered = false"
                                @pointercancel="finalDrag.cancel"
                                @keydown.enter.prevent="keyboardFinish"
                                @keydown.space.prevent="keyboardFinish"
                            />
                        </div>
                    </div>
                </div>
            </div>

            <img
                v-for="part in foregroundParts"
                :key="part"
                class="counter-scene-foreground"
                :class="`counter-scene-foreground--${part}`"
                :src="cashCounterImages.scene"
                alt=""
                draggable="false"
                aria-hidden="true"
            />

            <span class="scene-plaque scene-plaque--left">{{ t('cashCounter.toCount') }}</span>
            <span class="scene-plaque scene-plaque--right">{{ t('cashCounter.countedLabel') }}</span>

            <div
                class="counter-finish-zone"
                :class="{
                    'is-visible': store.allCollected || finalDrag.dragging.value || store.finished,
                    'is-over': finalDrag.over.value,
                    'is-complete': store.finished,
                }"
                data-cash-finish
                aria-hidden="true"
            >
                <span class="counter-finish-arrow">↓</span>
                <span>{{ finalHint }}</span>
            </div>

            <div v-if="finalDrag.dragging.value" class="counter-final-ghost" :style="finalGhostStyle" aria-hidden="true">
                <span
                    v-for="pile in rightPiles"
                    :key="pile.id"
                    class="counter-final-ghost-bundle"
                    :style="finalBundleStyle(pile.slot)"
                >
                    <CashPaper banded />
                </span>
                <span class="counter-drag-amount">{{ format(store.amount) }}</span>
            </div>

            <div
                v-if="feedDrag.dragging.value || collectDrag.dragging.value"
                class="counter-ghost"
                :style="{ left: `${activeDrag.x.value}px`, top: `${activeDrag.y.value}px` }"
            >
                <CashStacks compact :banded="collectDrag.dragging.value" />
                <span class="counter-drag-amount">{{ format(dragAmount) }}</span>
            </div>
        </section>
    </div>
</template>