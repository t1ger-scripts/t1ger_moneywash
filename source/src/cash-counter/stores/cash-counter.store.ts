import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { useUiStore } from '@/shared/stores/ui.store'
import { installLocaleMessages } from '@/integrations/i18n'
import { isFiveMEnvironment, postNui } from '@/integrations/nui'
import { NUI_CALLBACKS } from '@/integrations/nui'
import type { NuiResponse } from '@/integrations/nui'
import type {
    CashCounterPayload,
    CounterBatch,
    CounterStatus,
} from '../cash-counter.types'
import { validAmount } from '../utils/cash-counter.utils'

export const useCashCounterStore = defineStore('cash-counter', () => {
    const ui = useUiStore()
    const payload = ref<CashCounterPayload | null>(null)
    const amount = ref(0)
    const available = ref(0)
    const batch = ref<CounterBatch | null>(null)
    const receivedAt = ref(0)
    const submitting = ref(false)
    const error = ref('')
    let generation = 0
    let demoEnd = 0

    const busy = computed(() => submitting.value || !!batch.value)
    function applyBatch(value?: CounterBatch) {
        batch.value = value ?? null
        receivedAt.value = performance.now()
    }
    function applyStatus(data: CounterStatus) {
        available.value = data.available
        applyBatch(data.batch)
    }
    function open(data: CashCounterPayload) {
        generation++
        payload.value = data
        installLocaleMessages(data.locale, data.messages)
        available.value = Math.max(0, Math.floor(data.available))
        amount.value = data.batch?.amount ?? available.value
        applyBatch(data.batch)
        submitting.value = false
        error.value = ''
        ui.open('cash-counter')
    }
    async function start() {
        if (busy.value || !payload.value || !validAmount(amount.value, available.value)) return
        submitting.value = true
        error.value = ''
        const version = generation
        try {
            let response: NuiResponse<CounterStatus>
            if (!isFiveMEnvironment()) {
                const settings = payload.value.settings
                const pileCount = Math.min(settings.stackCount, amount.value)
                const durationMs = pileCount * settings.stackDurationMs
                demoEnd = performance.now() + durationMs
                response = { success: true, data: {
                    available: available.value,
                    batch: { id: Date.now(), amount: amount.value, durationMs,
                        remainingMs: durationMs, status: 'counting' },
                } }
            } else {
                response = await postNui<NuiResponse<CounterStatus>, { amount: number }>(
                    NUI_CALLBACKS.cashStart, { amount: amount.value },
                )
            }
            if (version !== generation) return
            if (response.success && response.data) applyStatus(response.data)
            else error.value = response.reason ?? 'request_failed'
        } catch {
            if (version === generation) error.value = 'request_failed'
        } finally {
            if (version === generation) submitting.value = false
        }
    }
    async function confirm() {
        if (submitting.value || batch.value?.status !== 'ready') return
        submitting.value = true
        error.value = ''
        const version = ++generation // Ignore a status poll started before confirmation.
        try {
            let response: NuiResponse<CounterStatus>
            if (!isFiveMEnvironment()) {
                response = { success: true, data: { available: available.value - batch.value.amount,
                    batch: { ...batch.value, remainingMs: 0, status: 'complete' } } }
            } else {
                response = await postNui<NuiResponse<CounterStatus>, { batchId: number }>(
                    NUI_CALLBACKS.cashConfirm, { batchId: batch.value.id },
                )
            }
            if (version !== generation) return
            if (response.data) applyStatus(response.data)
            if (!response.success) {
                error.value = response.reason ?? 'request_failed'
                if (!response.data?.batch) generation++ // Discard an in-flight old status poll.
            }
        } catch {
            if (version === generation) error.value = 'request_failed'
        } finally {
            submitting.value = false
        }
    }
    async function recount() {
        if (submitting.value || batch.value?.status !== 'ready') return
        submitting.value = true
        error.value = ''
        const version = ++generation // Ignore a status poll from the old count.
        try {
            const response = !isFiveMEnvironment()
                ? { success: true, data: { available: available.value } }
                : await postNui<NuiResponse<CounterStatus>, { batchId: number }>(
                    NUI_CALLBACKS.cashReset, { batchId: batch.value.id },
                )
            if (version !== generation) return
            if (response.success && response.data) {
                generation++
                applyStatus(response.data)
                amount.value = Math.min(amount.value, available.value)
            } else error.value = response.reason ?? 'request_failed'
        } catch {
            if (version === generation) error.value = 'request_failed'
        } finally {
            submitting.value = false
        }
    }
    async function refresh() {
        if (!payload.value || ui.activeScreen !== 'cash-counter') return
        const version = generation
        try {
            if (!isFiveMEnvironment()) {
                if (batch.value?.status === 'counting' && performance.now() >= demoEnd) {
                    applyBatch({ ...batch.value, status: 'ready', remainingMs: 0 })
                }
                return
            }
            const response = await postNui<NuiResponse<CounterStatus>>(NUI_CALLBACKS.cashStatus)
            if (version !== generation || !response.success || !response.data) return
            available.value = response.data.available
            if (response.data.batch) {
                applyBatch(response.data.batch)
                if (response.data.batch.status === 'complete') error.value = ''
            }
        } catch {
            // A later poll retries. No client-side timer can complete a real transaction.
        }
    }
    async function close() {
        generation++
        ui.close('cash-counter')
        if (isFiveMEnvironment()) {
            try { await postNui(NUI_CALLBACKS.cashClose) } catch { /* Lua cleans up on stop. */ }
        }
    }
    return { payload, amount, available, batch, receivedAt, submitting, busy, error,
        open, start, confirm, recount, refresh, close }
})
