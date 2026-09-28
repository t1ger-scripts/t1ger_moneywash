import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { useUiStore } from '@/stores/ui.store'
import { installLocaleMessages } from '@/integrations/localization/i18n'
import { isFiveMEnvironment, postNui } from '@/integrations/nui/nuiClient'
import { NUI_CALLBACKS } from '@/integrations/nui/nuiEvents'
import type { NuiResponse } from '@/integrations/nui/nui.types'
import type {
    CashCounterPayload,
    CounterBatch,
    CounterStatus,
} from './cash-counter.types'
import { counterDuration, validAmount } from './cash-counter.utils'
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
        if (
            busy.value ||
            !payload.value ||
            !validAmount(amount.value, available.value)
        )
            return
        submitting.value = true
        error.value = ''
        const version = generation
        try {
            let response: NuiResponse<CounterStatus>
            if (!isFiveMEnvironment()) {
                const durationMs = counterDuration(amount.value)
                demoEnd = performance.now() + durationMs
                response = {
                    success: true,
                    data: {
                        available: available.value - amount.value,
                        batch: {
                            id: Date.now(),
                            amount: amount.value,
                            durationMs,
                            remainingMs: durationMs,
                            status: 'counting',
                        },
                    },
                }
            } else {
                response = await postNui<
                    NuiResponse<CounterStatus>,
                    { amount: number }
                >(NUI_CALLBACKS.cashStart, { amount: amount.value })
            }
            if (version !== generation) return
            if (response.success && response.data) {
                available.value = response.data.available
                applyBatch(response.data.batch)
            } else error.value = response.reason ?? 'request_failed'
        } catch {
            // A lost response is ambiguous. Poll server status; never manufacture success.
            if (version === generation) error.value = 'request_failed'
        } finally {
            if (version === generation) submitting.value = false
        }
    }
    async function refresh() {
        if (!payload.value || ui.activeScreen !== 'cash-counter') return
        const version = generation
        try {
            if (!isFiveMEnvironment()) {
                if (
                    batch.value?.status === 'counting' &&
                    performance.now() >= demoEnd
                ) {
                    applyBatch({
                        ...batch.value,
                        status: 'complete',
                        remainingMs: 0,
                    })
                }
                return
            }
            const response = await postNui<NuiResponse<CounterStatus>>(
                NUI_CALLBACKS.cashStatus,
            )
            if (version !== generation || !response.success || !response.data)
                return
            available.value = response.data.available
            if (response.data.batch) {
                applyBatch(response.data.batch)
                error.value = ''
            }
        } catch {
            /* The next poll retries. Keep waiting for an authoritative result. */
        }
    }
    async function close() {
        ui.close('cash-counter')
        if (isFiveMEnvironment()) {
            try {
                await postNui(NUI_CALLBACKS.cashClose)
            } catch {
                /* Lua also cleans up on stop. */
            }
        }
    }
    return {
        payload,
        amount,
        available,
        batch,
        receivedAt,
        submitting,
        busy,
        error,
        open,
        start,
        refresh,
        close,
    }
})
