<script setup lang="ts">
import {
    computed,
    nextTick,
    onMounted,
    onUnmounted,
    ref,
    watch,
} from 'vue'
import { useI18n } from 'vue-i18n'
import CashStacks from './components/CashStacks.vue'
import CounterMachine from './components/CounterMachine.vue'
import { useCashCounterStore } from './stores/cash-counter.store'
import { useCashDrag } from './composables/useCashDrag'
import { useCounterSound } from './composables/useCounterSound'
import { cashCounterImages, trayPilePosition, validAmount } from './utils/cash-counter.utils'
import type { CashPile } from './cash-counter.types'
import './styles/cash-counter.scss'
import './styles/cash-counter-scene.scss'
import './styles/cash-counter-paper.scss'

const store = useCashCounterStore()
const sound = useCounterSound()
const { t, te } = useI18n()

const root = ref<HTMLElement | null>(null)

const foregroundParts = [
    'left-tray',
    'right-tray',
    'input',
    'output',
] as const

const selectedPileId = ref<number | null>(null)

const leftPiles = computed<CashPile[]>(() =>
    store.piles
        .flatMap((amount, id) => {
            if (
                store.completedPileIds.includes(id) ||
                store.activePileId === id
            ) return []

            return [{ id, amount, slot: id }]
        })
        .map((pile, slot) => ({
            ...pile,
            slot,
        })),
)

const rightPiles = computed<CashPile[]>(() =>
    store.completedPileIds.map((id, slot) => ({
        id,
        amount: store.piles[id] ?? 0,
        slot,
    })),
)

const format = (amount: number) =>
    `${store.payload?.currency ?? '$'}${Math.floor(
        Math.max(0, amount),
    ).toLocaleString(store.payload?.locale ?? 'en')}`

const complete = computed(() => store.batch?.status === 'complete')
const settling = computed(() => store.batch?.status === 'settling')
const reviewing = computed(() => store.batch?.status === 'review')

async function loadPile() {
    const id = selectedPileId.value
    if (id === null) return

    sound.prime()
    await store.loadPile(id)

    if (store.running) sound.loaded()
}

function collectPile() {
    sound.prime()
    if (store.canCollect) store.collectPile()
}

const feedDrag = useCashDrag(
    root,
    () => store.canLoad,
    loadPile,
)

const collectDrag = useCashDrag(
    root,
    () => store.canCollect,
    collectPile,
    '[data-cash-output]',
)

const activeDrag = computed(() =>
    collectDrag.dragging.value ? collectDrag : feedDrag,
)

const dragAmount = computed(() => {
    if (collectDrag.dragging.value) return store.activeAmount

    const id = selectedPileId.value
    return id === null ? 0 : store.piles[id] ?? 0
})

const landingStyle = computed(() =>
    trayPilePosition(store.collected, rightPiles.value.length + 1)
)

function keyboardLoad(id: number) {
    sound.prime()

    if (
        !store.canLoad ||
        feedDrag.dragging.value ||
        collectDrag.dragging.value
    ) return

    selectedPileId.value = id

    const pile = root.value?.querySelector<HTMLElement>(
        `.counter-pile [data-pile-id="${id}"]`,
    )

    if (pile) void feedDrag.transfer(pile)
}

function pickPile(event: PointerEvent, id: number) {
    if (
        !store.canLoad ||
        feedDrag.dragging.value ||
        collectDrag.dragging.value
    ) return

    selectedPileId.value = id
    sound.prime()
    feedDrag.down(event)
}

function keyboardCollect() {
    sound.prime()

    if (feedDrag.dragging.value || collectDrag.dragging.value) return

    const pile = root.value?.querySelector<HTMLElement>(
        '[data-cash-collect]',
    )

    if (pile) void collectDrag.transfer(pile)
}

const status = computed(() => {
    if (complete.value) return t('cashCounter.complete')
    if (settling.value) return t('cashCounter.confirming')
    if (reviewing.value) return t('cashCounter.errors.manual_review')
    if (store.submitting) return t('common.loading')

    if (store.running) {
        return t('cashCounter.countingPile', {
            current: store.collected + 1,
            total: store.piles.length,
        })
    }

    if (store.canCollect) return t('cashCounter.collectReady')

    if (store.allCollected) {
        return t(
            store.canConfirm
                ? 'cashCounter.readyToConfirm'
                : 'cashCounter.waitingForServer',
        )
    }

    return t('cashCounter.ready')
})

const feederLabel = computed(() => {
    if (feedDrag.over.value) return t('cashCounter.releasePile')
    if (complete.value) return t('cashCounter.complete')
    if (settling.value) return t('cashCounter.confirming')
    if (store.running) return t('cashCounter.counting')
    if (store.canCollect) return t('cashCounter.collectReady')
    if (store.allCollected) return t('cashCounter.batchComplete')

    return t(
        store.batch
            ? 'cashCounter.nextPile'
            : 'cashCounter.dropHere',
    )
})

const displayState = computed(() => {
    if (complete.value) return t('cashCounter.complete')
    if (settling.value) return t('cashCounter.confirming')
    if (store.running) return t('cashCounter.counting')
    if (store.canCollect) return t('cashCounter.collectReady')
    if (store.allCollected) return t('cashCounter.batchComplete')

    return t('cashCounter.awaiting')
})

const errorMessage = computed(() => {
    if (reviewing.value) return t('cashCounter.errors.manual_review')

    if (store.error) {
        const key = `cashCounter.errors.${store.error}`

        return t(
            te(key)
                ? key
                : 'cashCounter.errors.request_failed',
        )
    }

    if (
        !store.busy &&
        store.amount > 0 &&
        !validAmount(store.amount, store.available)
    ) return t('cashCounter.errors.invalid_amount')

    return ''
})

watch(() => store.running, (running) => {
    if (running) sound.start()
    else sound.stop()
})

watch(() => store.phase, async (phase, previous) => {
    if (previous === 'counting' && phase !== 'counting') {
        sound.counted()
    }

    if (
        phase !== 'collect' ||
        !store.settings?.autoMoveToRight
    ) return

    const session = store.payload

    await nextTick()

    if (
        session !== store.payload ||
        !store.canCollect ||
        collectDrag.dragging.value
    ) return

    const pile = root.value?.querySelector<HTMLElement>(
        '[data-cash-collect]',
    )

    if (pile) await collectDrag.transfer(pile)
})

watch(() => store.collected, (count, previous) => {
    if (count > previous && !complete.value) {
        sound.placed()
    }
})

let closeTimer = 0

watch(complete, (value) => {
    clearTimeout(closeTimer)

    if (!value) return

    sound.deposited()
    feedDrag.cancel()
    collectDrag.cancel()

    const session = store.payload
    const batchId = store.batch?.id

    closeTimer = window.setTimeout(() => {
        if (
            store.payload === session &&
            store.batch?.id === batchId &&
            store.batch?.status === 'complete'
        ) {
            void store.close()
        }
    }, 1200)
})

function escape(event: KeyboardEvent) {
    if (
        event.key === 'Escape' &&
        (feedDrag.dragging.value || collectDrag.dragging.value)
    ) {
        event.preventDefault()
        feedDrag.cancel()
        collectDrag.cancel()
    }
}

let animation = 0
let poll = 0
let polling = false

async function refresh() {
    if (polling) return

    polling = true

    try {
        await store.refresh()
    } finally {
        polling = false
    }
}

onMounted(() => {

    function tick() {
        store.tick(performance.now())

        if (store.running && store.settings) {
            sound.feed(store.settings.stackDurationMs / 12)
        }

        animation = requestAnimationFrame(tick)
    }

    tick()
    poll = window.setInterval(() => void refresh(), 250)
    document.addEventListener('keydown', escape)
})

onUnmounted(() => {
    cancelAnimationFrame(animation)
    clearInterval(poll)
    clearTimeout(closeTimer)
    feedDrag.cancel()
    collectDrag.cancel()
    sound.dispose()
    document.removeEventListener('keydown', escape)
})
</script>

<template>
    <div class="cash-counter-overlay cash-counter-overlay--scene">
        <section ref="root" class="cash-counter cash-counter--scene" role="dialog" aria-modal="true"
            aria-labelledby="cash-counter-title">
            <img class="counter-scene-image" :src="cashCounterImages.scene" alt="" draggable="false" />

            <h1 id="cash-counter-title" class="counter-sr-only">
                {{
                    t(
                        store.payload?.titleKey ??
                        'cashCounter.injectTitle'
                    )
                }}
            </h1>

            <span class="counter-sr-only" role="status">
                {{ status }}
            </span>

            <button class="counter-scene-close" type="button" :aria-label="t('common.close')" @click="store.close">
                <kbd>ESC</kbd>
                <span>{{ t('common.close') }}</span>
            </button>

            <p v-if="errorMessage" class="counter-error" role="alert">
                {{ errorMessage }}
            </p>

            <div class="counter-desk">
                <div class="counter-source">
                    <div class="counter-cash-tray">
                        <div class="counter-pile">
                            <CashStacks :items="leftPiles" :total-slots="leftPiles.length" :format="format" interactive
                                :disabled="!store.canLoad" :lifted-id="feedDrag.dragging.value
                                    ? selectedPileId
                                    : null
                                    " @pick="pickPile" @move="feedDrag.move" @release="feedDrag.up"
                                @cancel="feedDrag.cancel" @load="keyboardLoad" />
                        </div>
                    </div>
                </div>

                <CounterMachine :value="format(store.countedAmount)" :display-state="displayState"
                    :feeder-label="feederLabel" :running="store.running" :over="feedDrag.over.value" :duration-ms="store.settings?.stackDurationMs ?? 800
                        " :collectable="store.canCollect" :collect-label="t('cashCounter.collectPile', {
                            amount: format(store.activeAmount),
                        })
                            " :lifted="collectDrag.dragging.value" :progress="store.progress" :complete="complete"
                    @collect-down="
                        sound.prime();
                    collectDrag.down($event)
                        " @collect-move="collectDrag.move" @collect-up="collectDrag.up"
                    @collect-cancel="collectDrag.cancel" @collect="keyboardCollect" />

                <div class="counter-output" :class="{
                    'is-ready': store.allCollected,
                    'is-target': collectDrag.dragging.value,
                    'is-over': collectDrag.over.value,
                    'is-complete': complete,
                }">
                    <div class="counter-tray" data-cash-output>
                        <CashStacks :items="rightPiles" :total-slots="rightPiles.length" :format="format" />

                        <span class="cash-stacks counter-stack-target" aria-hidden="true">
                            <span data-cash-landing :style="landingStyle" />
                        </span>
                    </div>
                </div>
            </div>

            <img v-for="part in foregroundParts" :key="part" class="counter-scene-foreground"
                :class="`counter-scene-foreground--${part}`" :src="cashCounterImages.scene" alt="" draggable="false"
                aria-hidden="true" />

            <span class="scene-plaque scene-plaque--left">
                {{ t('cashCounter.toCount') }}
            </span>

            <span class="scene-plaque scene-plaque--right">
                {{ t('cashCounter.countedLabel') }}
            </span>

            <div class="scene-confirmation">
                <button v-if="complete" class="counter-tray-confirm is-complete" type="button" disabled>
                    {{ t('cashCounter.complete') }}
                </button>

                <button v-else-if="store.allCollected || settling" class="counter-tray-confirm" type="button"
                    :disabled="!store.canConfirm" @click="store.confirm">
                    {{
                        store.submitting || settling
                            ? t('cashCounter.confirming')
                            : t('cashCounter.confirmAmount', {
                                amount: format(
                                    store.batch?.amount ??
                                    store.amount
                                ),
                            })
                    }}
                </button>
            </div>

            <div v-if="
                feedDrag.dragging.value ||
                collectDrag.dragging.value
            " class="counter-ghost" :style="{
                left: `${activeDrag.x.value}px`,
                top: `${activeDrag.y.value}px`,
            }">
                <CashStacks compact />
                <span>{{ format(dragAmount) }}</span>
            </div>
        </section>
    </div>
</template>