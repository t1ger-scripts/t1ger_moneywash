<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { X } from '@lucide/vue'
import CashStacks from './components/CashStacks.vue'
import CounterMachine from './components/CounterMachine.vue'
import CounterAmountSelector from './components/CounterAmountSelector.vue'
import { useCashCounterStore } from './cash-counter.store'
import { useCashDrag } from './composables/useCashDrag'
import { validAmount } from './cash-counter.utils'
import { createCashTextures } from './cash-counter.textures'
import { isFiveMEnvironment } from '@/integrations/nui/nuiClient'
import './cash-counter.scss'
const store = useCashCounterStore()
const { t, te } = useI18n()
const root = ref<HTMLElement | null>(null)
const textures = ref<Record<string, string>>({})
const now = ref(performance.now())
const demo = import.meta.env.DEV && !isFiveMEnvironment()
const demoBalance = ref(10000000)
const format = (n: number) =>
    `${store.payload?.currency ?? '$'}${Math.floor(Math.max(0, n)).toLocaleString(store.payload?.locale ?? 'en')}`
const valid = computed(() => validAmount(store.amount, store.available))
const progress = computed(() => {
    const b = store.batch
    if (!b) return 0
    if (b.status === 'review') return 0
    if (b.status === 'complete') return 1
    return Math.max(
        0,
        Math.min(
            1,
            1 - (b.remainingMs - (now.value - store.receivedAt)) / b.durationMs,
        ),
    )
})
const complete = computed(() => store.batch?.status === 'complete')
const counting = computed(() => store.batch?.status === 'counting')
const shownCash = computed(() =>
    store.batch
        ? Math.floor(store.batch.amount * (1 - progress.value))
        : valid.value
            ? store.amount
            : 0,
)
const counted = computed(() =>
    store.batch ? Math.floor(store.batch.amount * progress.value) : 0,
)
const status = computed(() =>
    t(
        complete.value
            ? 'cashCounter.complete'
            : counting.value
                ? 'cashCounter.counting'
                : 'cashCounter.ready',
    ),
)
const errorMessage = computed(() => {
    if (store.batch?.status === 'review')
        return t('cashCounter.errors.manual_review')

    if (store.error)
        return t(
            te(`cashCounter.errors.${store.error}`)
                ? `cashCounter.errors.${store.error}`
                : 'cashCounter.errors.request_failed',
        )

    if (!store.busy && store.amount > store.available)
        return t('cashCounter.errors.invalid_amount')

    return ''
})
const drag = useCashDrag(
    root,
    () => !store.busy && valid.value,
    () => {
        void store.start()
    },
)
let animation = 0,
    poll = 0,
    polling = false
async function refresh() {
    if (polling) return
    polling = true
    try {
        await store.refresh()
    } finally {
        polling = false
    }
}
async function changeDemo() {
    if (!import.meta.env.DEV) return
    const { openCounterDemo } = await import('./cash-counter.demo')
    openCounterDemo(demoBalance.value)
}
function escape(event: KeyboardEvent) {
    if (event.key === 'Escape' && drag.dragging.value) {
        event.preventDefault()
        drag.cancel()
    }
}
onMounted(() => {
    textures.value = createCashTextures()
    function tick() {
        now.value = performance.now()
        animation = requestAnimationFrame(tick)
    }
    tick()
    poll = window.setInterval(() => {
        void refresh()
    }, 750)
    document.addEventListener('keydown', escape)
})
onUnmounted(() => {
    cancelAnimationFrame(animation)
    clearInterval(poll)
    drag.cancel()
    document.removeEventListener('keydown', escape)
})
</script>
<template>
    <div class="cash-counter-overlay">
        <div v-if="demo" class="counter-demo">
            <span>DEMO</span><label>Inventory
                <select v-model.number="demoBalance" :disabled="store.busy" @change="changeDemo">
                    <option :value="15000">$15,000</option>
                    <option :value="1000000">$1,000,000</option>
                    <option :value="10000000">$10,000,000</option>
                </select></label>
        </div>
        <section ref="root" class="cash-counter" :style="textures" role="dialog" aria-modal="true"
            aria-labelledby="cash-counter-title">
            <header class="counter-header">
                <h1 id="cash-counter-title">
                    {{
                        t(store.payload?.titleKey ?? 'cashCounter.injectTitle')
                    }}
                </h1>
                <div class="counter-balance">
                    <span>{{ t('cashCounter.available') }}</span><strong>{{ format(store.available) }}</strong>
                </div>
                <span class="counter-status">{{ status }}</span><button class="counter-close" type="button"
                    :aria-label="t('common.close')" @click="store.close">
                    <X :size="16" />
                </button>
            </header>
            <p v-if="errorMessage" class="counter-error" role="alert">
                {{ errorMessage }}
            </p>
            <div class="counter-desk">
                <div class="counter-source">
                    <div class="counter-cash-tray">
                        <button class="counter-pile" :class="{ 'is-dragging': drag.dragging.value }" type="button"
                            :disabled="store.busy || !valid" :aria-label="t('cashCounter.load', {
                                amount: format(store.amount),
                            })
                                " @pointerdown="drag.down" @pointermove="drag.move" @pointerup="drag.up"
                            @pointercancel="drag.cancel" @keydown.enter.prevent="store.start"
                            @keydown.space.prevent="store.start">
                            <CashStacks :amount="shownCash" />
                        </button>
                    </div>

                    <small>{{
                        t(
                            counting
                                ? 'cashCounter.waitingToFeed'
                                : 'cashCounter.selectedBatch',
                        )
                    }}</small>
                </div>
                <CounterMachine :value="format(counted)" :display-state="t(
                    complete
                        ? 'cashCounter.cashInjected'
                        : counting
                            ? 'cashCounter.counting'
                            : 'cashCounter.awaiting',
                )
                    " :running="counting && progress < 1" :over="drag.over.value" :feeder-label="drag.over.value
                        ? t('cashCounter.release', {
                            amount: format(store.amount),
                        })
                        : t(
                            complete
                                ? 'cashCounter.batchComplete'
                                : counting
                                    ? 'cashCounter.autoFeed'
                                    : 'cashCounter.dropHere',
                        )
                        " />
                <div class="counter-output">
                    <div class="counter-tray">
                        <span v-for="i in 5" :key="i" class="cash-bundle" :style="{
                            opacity: Math.max(
                                0,
                                Math.min(1, (progress - (i - 1) / 5) * 5),
                            ),
                            bottom: 15 + (i - 1) * 16 + 'px',
                        }" />
                    </div>
                    <small>{{ t('cashCounter.countedCash') }}</small>
                </div>
            </div>
            <CounterAmountSelector v-model="store.amount" :available="store.available" :disabled="store.busy"
                :format="format" />
            <div v-if="drag.dragging.value" class="counter-ghost"
                :style="{ left: drag.x.value + 'px', top: drag.y.value + 'px' }">
                <CashStacks :amount="store.amount" compact /><span>{{
                    format(store.amount)
                }}</span>
            </div>
        </section>
    </div>
</template>
