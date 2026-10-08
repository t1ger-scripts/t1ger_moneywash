import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { useUiStore } from '@/shared/stores/ui.store'
import { installLocaleMessages } from '@/integrations/i18n'
import {
    postNui,
    NUI_CALLBACKS,
    type NuiCallbackName,
    type NuiResponse,
} from '@/integrations/nui'
import type {
    CashCounterPayload,
    CounterBatch,
    CounterPhase,
    CounterStatus,
} from '../cash-counter.types'
import { splitCash, validAmount } from '../utils/cash-counter.utils'

export const useCashCounterStore = defineStore('cash-counter', () => {
    const ui = useUiStore()

    const payload = ref<CashCounterPayload | null>(null)
    const amount = ref(0)
    const available = ref(0)
    const batch = ref<CounterBatch | null>(null)
    const submitting = ref(false)
    const error = ref('')

    const phase = ref<CounterPhase>('idle')
    const completedPileIds = ref<number[]>([])
    const activePileId = ref<number | null>(null)

    const collected = computed(() => completedPileIds.value.length)
    const progress = ref(0)

    let generation = 0
    let startedAt = 0

    const settings = computed(
        () => batch.value?.settings ?? payload.value?.settings,
    )

    const busy = computed(() => submitting.value || !!batch.value)

    const piles = computed(() => {
        if (!settings.value) return []

        if (!batch.value && !validAmount(amount.value, available.value)) {
            return []
        }

        return splitCash(
            batch.value?.amount ?? amount.value,
            settings.value.stackCount,
        )
    })

    const activeAmount = computed(() => {
        const id = activePileId.value
        return id === null ? 0 : piles.value[id] ?? 0
    })

    const activeBatch = computed(
        () => batch.value?.status === 'counting' ||
            batch.value?.status === 'ready',
    )

    const running = computed(
        () => activeBatch.value && phase.value === 'counting',
    )

    const canLoad = computed(
        () => !!payload.value &&
            !submitting.value &&
            phase.value === 'idle' &&
            collected.value < piles.value.length &&
            (!batch.value || activeBatch.value),
    )

    const canCollect = computed(
        () => activeBatch.value &&
            !submitting.value &&
            phase.value === 'collect' &&
            activePileId.value !== null,
    )

    const allCollected = computed(
        () => !!batch.value &&
            piles.value.length > 0 &&
            collected.value === piles.value.length &&
            phase.value === 'idle',
    )

    const canConfirm = computed(
        () => allCollected.value &&
            batch.value?.status === 'ready' &&
            !submitting.value,
    )

    const countedAmount = computed(() => {
        const finished = completedPileIds.value.reduce(
            (sum, id) => sum + (piles.value[id] ?? 0),
            0,
        )

        if (phase.value === 'collect') {
            return finished + activeAmount.value
        }

        if (phase.value === 'counting') {
            return finished + Math.floor(
                activeAmount.value * progress.value,
            )
        }

        return finished
    })

    function resetSequence() {
        phase.value = 'idle'
        completedPileIds.value = []
        activePileId.value = null
        progress.value = 0
        startedAt = 0
    }

    function applyBatch(value?: CounterBatch, forceReset = false) {
        const next = value ?? null

        if (forceReset || next?.id !== batch.value?.id) {
            resetSequence()
        }

        batch.value = next

        if (next?.status === 'complete') {
            if (completedPileIds.value.length !== piles.value.length) {
                completedPileIds.value = piles.value.map((_, id) => id)
            }

            activePileId.value = null
            phase.value = 'idle'
            progress.value = 0
        }

        if (next?.status === 'review' || next?.status === 'settling') {
            phase.value = 'idle'
            progress.value = 0
        }
    }

    function applyStatus(data: CounterStatus) {
        available.value = Math.max(0, Math.floor(data.available))
        applyBatch(data.batch)
    }

    function open(data: CashCounterPayload) {
        generation++
        payload.value = data

        installLocaleMessages(data.locale, data.messages)

        available.value = Math.max(0, Math.floor(data.available))
        amount.value = data.batch?.amount ?? data.amount

        applyBatch(data.batch, true)
        submitting.value = false
        error.value = ''

        ui.open('cash-counter')
    }

    async function request(
        callback: NuiCallbackName,
        data: Record<string, number>,
    ): Promise<boolean> {
        if (submitting.value || !payload.value) return false

        const version = ++generation
        submitting.value = true
        error.value = ''

        try {
            const response = await postNui<
                NuiResponse<CounterStatus>,
                Record<string, number>
            >(callback, data)

            if (version !== generation) return false

            if (response.data) applyStatus(response.data)

            if (!response.success) {
                error.value = response.reason ?? 'request_failed'
                return false
            }

            if (!response.data) {
                error.value = 'request_failed'
                return false
            }

            return true
        } catch {
            if (version === generation) {
                error.value = 'request_failed'
            }

            return false
        } finally {
            if (version === generation) submitting.value = false
        }
    }

    async function loadPile(pileId: number) {
        if (
            !canLoad.value ||
            !Number.isInteger(pileId) ||
            pileId < 0 ||
            pileId >= piles.value.length ||
            completedPileIds.value.includes(pileId)
        ) return

        const session = payload.value

        if (!batch.value) {
            const accepted = await request(
                NUI_CALLBACKS.cashStart,
                { amount: amount.value },
            )

            if (!accepted) return
        }

        if (
            payload.value !== session ||
            !batch.value ||
            !canLoad.value ||
            pileId >= piles.value.length ||
            completedPileIds.value.includes(pileId)
        ) return

        activePileId.value = pileId
        progress.value = 0
        startedAt = performance.now()
        phase.value = 'counting'
    }

    function collectPile() {
        if (!canCollect.value || activePileId.value === null) return

        const id = activePileId.value

        if (!completedPileIds.value.includes(id)) {
            completedPileIds.value.push(id)
        }

        activePileId.value = null
        progress.value = 0
        phase.value = 'idle'
    }

    function tick(now: number) {
        if (!running.value || !settings.value) return

        const duration = Math.max(100, settings.value.stackDurationMs)

        progress.value = Math.min(
            1,
            Math.max(0, (now - startedAt) / duration),
        )

        if (progress.value < 1) return

        phase.value = 'collect'
    }

    async function confirm() {
        if (!canConfirm.value || !batch.value) return

        await request(
            NUI_CALLBACKS.cashConfirm,
            { batchId: batch.value.id },
        )
    }

    async function refresh() {
        if (
            !payload.value ||
            submitting.value ||
            ui.activeScreen !== 'cash-counter'
        ) return

        const version = generation

        try {
            const response = await postNui<NuiResponse<CounterStatus>>(
                NUI_CALLBACKS.cashStatus,
            )

            if (
                version !== generation ||
                !response.success ||
                !response.data
            ) return

            applyStatus(response.data)

            if (batch.value?.status === 'complete') {
                error.value = ''
            }
        } catch {
            // The next poll retries. Transactions never complete locally.
        }
    }

    function dismiss() {
        generation++
        ui.close('cash-counter')
        payload.value = null
        batch.value = null
        submitting.value = false
        error.value = ''
        resetSequence()
    }

    async function close() {
        dismiss()

        try {
            await postNui(NUI_CALLBACKS.cashClose)
        } catch {
            // Resource shutdown also performs server-side cleanup.
        }
    }

    return {
        payload,
        amount,
        available,
        batch,
        settings,
        submitting,
        error,
        busy,
        phase,
        collected,
        progress,
        piles,
        activeAmount,
        running,
        canLoad,
        canCollect,
        allCollected,
        canConfirm,
        countedAmount,
        open,
        loadPile,
        collectPile,
        tick,
        confirm,
        refresh,
        dismiss,
        close,
        completedPileIds,
        activePileId,
    }
})