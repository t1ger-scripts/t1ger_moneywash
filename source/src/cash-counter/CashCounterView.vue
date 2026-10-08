<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { X } from '@lucide/vue'
import CashStacks from './components/CashStacks.vue'
import CounterMachine from './components/CounterMachine.vue'
import CounterAmountSelector from './components/CounterAmountSelector.vue'
import { useCashCounterStore } from './stores/cash-counter.store'
import { useCashDrag } from './composables/useCashDrag'
import { useCounterSound } from './composables/useCounterSound'
import { createCashTextures } from './utils/cash-counter.textures'
import { validAmount } from './utils/cash-counter.utils'
import './styles/cash-counter.scss'

const store = useCashCounterStore()
const sound = useCounterSound()
const { t, te } = useI18n()

const root = ref<HTMLElement | null>(null)
const textures = ref<Record<string, string>>({})

const format = (amount: number) =>
    `${store.payload?.currency ?? '$'}${Math.floor(
        Math.max(0, amount),
    ).toLocaleString(store.payload?.locale ?? 'en')}`

const complete = computed(() => store.batch?.status === 'complete')
const settling = computed(() => store.batch?.status === 'settling')
const reviewing = computed(() => store.batch?.status === 'review')

function loadPile() {
    sound.prime()
    void store.loadPile()
}

function collectPile() {
    sound.prime()
    if (!store.canCollect) return

    store.collectPile()
    sound.deposited()
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
    if (complete.value) return t('cashCounter.deposited')
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
    if (complete.value) return t('cashCounter.deposited')
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

watch(() => store.phase, (phase, previous) => {
    if (previous === 'counting' && phase !== 'counting') {
        sound.counted()
    }
})

watch(complete, (value) => {
    if (value) sound.deposited()
})

async function recount() {
    if (!store.canConfirm) return

    feedDrag.cancel()
    collectDrag.cancel()
    await store.recount()
}

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
    textures.value = createCashTextures()

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
    feedDrag.cancel()
    collectDrag.cancel()
    sound.dispose()
    document.removeEventListener('keydown', escape)
})
</script>

<template>
    <div class="cash-counter-overlay">
        <section
            ref="root"
            class="cash-counter"
            :style="textures"
            role="dialog"
            aria-modal="true"
            aria-labelledby="cash-counter-title"
        >
            <header class="counter-header">
                <h1 id="cash-counter-title">
                    {{
                        t(
                            store.payload?.titleKey ??
                            'cashCounter.injectTitle'
                        )
                    }}
                </h1>

                <div class="counter-balance">
                    <span>{{ t('cashCounter.available') }}</span>
                    <strong>{{ format(store.available) }}</strong>
                </div>

                <span class="counter-status">{{ status }}</span>

                <button
                    class="counter-close"
                    type="button"
                    :aria-label="t('common.close')"
                    @click="store.close"
                >
                    <X :size="16" />
                </button>
            </header>

            <p v-if="errorMessage" class="counter-error" role="alert">
                {{ errorMessage }}
            </p>

            <div class="counter-desk">
                <div class="counter-source">
                    <div class="counter-cash-tray">
                        <button
                            class="counter-pile"
                            type="button"
                            :disabled="!store.canLoad"
                            :aria-label="t('cashCounter.loadPile', {
                                amount: format(store.activeAmount),
                            })"
                            @pointerdown="feedDrag.down"
                            @pointermove="feedDrag.move"
                            @pointerup="feedDrag.up"
                            @pointercancel="feedDrag.cancel"
                            @keydown.enter.prevent="loadPile"
                            @keydown.space.prevent="loadPile"
                        >
                            <CashStacks
                                :count="store.leftCount"
                                :lifted="feedDrag.dragging.value"
                            />
                        </button>
                    </div>
                </div>

                <CounterMachine
                    :value="format(store.countedAmount)"
                    :display-state="displayState"
                    :feeder-label="feederLabel"
                    :running="store.running"
                    :over="feedDrag.over.value"
                    :duration-ms="store.settings?.stackDurationMs ?? 800"
                    :collectable="store.canCollect"
                    :collect-label="t('cashCounter.collectPile', {
                        amount: format(store.activeAmount),
                    })"
                    :lifted="collectDrag.dragging.value"
                    @collect-down="collectDrag.down"
                    @collect-move="collectDrag.move"
                    @collect-up="collectDrag.up"
                    @collect-cancel="collectDrag.cancel"
                    @collect="collectPile"
                />

                <div
                    class="counter-output"
                    :class="{
                        'is-ready': store.allCollected,
                        'is-over': collectDrag.over.value,
                    }"
                >
                    <div class="counter-tray" data-cash-output>
                        <CashStacks :count="store.collected" />
                    </div>

                    <small>
                        {{
                            collectDrag.over.value
                                ? t('cashCounter.releaseRight')
                                : t('cashCounter.collectedPiles', {
                                    current: store.collected,
                                    total: store.piles.length,
                                })
                        }}
                    </small>
                </div>
            </div>

            <div class="counter-bottom">
                <CounterAmountSelector
                    v-model="store.amount"
                    :available="store.available"
                    :disabled="store.busy"
                    :format="format"
                />

                <div class="counter-final-actions">
                    <button
                        type="button"
                        class="counter-recount"
                        :disabled="!store.canConfirm"
                        @click="recount"
                    >
                        {{ t('cashCounter.recount') }}
                    </button>

                    <button
                        type="button"
                        class="counter-confirm"
                        :disabled="!store.canConfirm"
                        @click="store.confirm"
                    >
                        {{
                            t('cashCounter.confirmAmount', {
                                amount: format(
                                    store.batch?.amount ?? store.amount,
                                ),
                            })
                        }}
                    </button>
                </div>
            </div>

            <div
                v-if="feedDrag.dragging.value || collectDrag.dragging.value"
                class="counter-ghost"
                :style="{
                    left: `${activeDrag.x.value}px`,
                    top: `${activeDrag.y.value}px`,
                }"
            >
                <CashStacks compact />
                <span>{{ format(store.activeAmount) }}</span>
            </div>
        </section>
    </div>
</template>