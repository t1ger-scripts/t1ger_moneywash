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
    const collected = ref(0)
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

    const activeAmount = computed(
        () => piles.value[collected.value] ?? 0,
    )

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
            phase.value === 'collect',
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

    const leftCount = computed(
        () => Math.max(
            0,
            piles.value.length -
                collected.value -
                (phase.value === 'idle' ? 0 : 1),
        ),
    )

    const countedAmount = computed(() => {
        const finished = piles.value
            .slice(0, collected.value)
            .reduce((sum, value) => sum + value, 0)

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
        collected.value = 0
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
            collected.value = piles.value.length
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

        if (!batch.value) {
            amount.value = Math.min(amount.value, available.value)
        }
    }

    function open(data: CashCounterPayload) {
        generation++
        payload.value = data

        installLocaleMessages(data.locale, data.messages)

        available.value = Math.max(0, Math.floor(data.available))
        amount.value = data.batch?.amount ?? available.value

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

    async function loadPile() {
        if (!canLoad.value) return

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
            !canLoad.value
        ) return

        progress.value = 0
        startedAt = performance.now()
        phase.value = 'counting'
    }

    function collectPile() {
        if (!canCollect.value) return

        collected.value++
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

    async function recount() {
        if (!canConfirm.value || !batch.value) return

        await request(
            NUI_CALLBACKS.cashReset,
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
        leftCount,
        countedAmount,
        open,
        loadPile,
        collectPile,
        tick,
        confirm,
        recount,
        refresh,
        dismiss,
        close,
    }
})