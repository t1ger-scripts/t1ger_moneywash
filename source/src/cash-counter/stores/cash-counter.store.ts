import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { useUiStore } from '@/shared/stores/ui.store'
import { installLocaleMessages } from '@/integrations/i18n'
import { postNui, NUI_CALLBACKS } from '@/integrations/nui'
import type { CashCounterPayload, CounterPhase } from '../cash-counter.types'
import { COUNT_DURATION_MS, splitCash } from '../utils/cash-counter.utils'

/**
 * Cash counter minigame. Visual only: it counts the amount it was opened with
 * and tells Lua whether the player finished or closed it.
 */
export const useCashCounterStore = defineStore('cash-counter', () => {
    const ui = useUiStore()

    const payload = ref<CashCounterPayload | null>(null)
    const phase = ref<CounterPhase>('idle')
    const completedPileIds = ref<number[]>([])
    const activePileId = ref<number | null>(null)
    const progress = ref(0)
    const finished = ref(false)

    let startedAt = 0

    const settings = computed(() => payload.value?.settings)
    const amount = computed(() => payload.value?.amount ?? 0)

    const piles = computed(() => {
        if (!settings.value) return []

        return splitCash(
            amount.value,
            Math.min(10, Math.max(1, settings.value.stackCount)),
        )
    })

    const collected = computed(() => completedPileIds.value.length)

    const started = computed(
        () => collected.value > 0 || activePileId.value !== null,
    )

    const activeAmount = computed(() => {
        const id = activePileId.value
        return id === null ? 0 : piles.value[id] ?? 0
    })

    const running = computed(() => phase.value === 'counting')

    const canLoad = computed(
        () => !!payload.value &&
            !finished.value &&
            phase.value === 'idle' &&
            collected.value < piles.value.length,
    )

    const canCollect = computed(
        () => !finished.value &&
            phase.value === 'collect' &&
            activePileId.value !== null,
    )

    const allCollected = computed(
        () => piles.value.length > 0 &&
            collected.value === piles.value.length &&
            phase.value === 'idle',
    )

    const canFinish = computed(
        () => allCollected.value && !finished.value,
    )

    const countedAmount = computed(() => {
        const done = completedPileIds.value.reduce(
            (sum, id) => sum + (piles.value[id] ?? 0),
            0,
        )

        if (phase.value === 'collect') {
            return done + activeAmount.value
        }

        if (phase.value === 'counting') {
            return done + Math.floor(
                activeAmount.value * progress.value,
            )
        }

        return done
    })

    function reset() {
        phase.value = 'idle'
        completedPileIds.value = []
        activePileId.value = null
        progress.value = 0
        finished.value = false
        startedAt = 0
    }

    /** Lua opened the counter. Starts from a clean state every time. */
    function open(data: CashCounterPayload) {
        payload.value = data

        installLocaleMessages(data.locale, data.messages)

        reset()
        ui.open('cash-counter')
    }

    /** Puts a pile into the machine and starts counting it. */
    function loadPile(pileId: number) {
        if (
            !canLoad.value ||
            !Number.isInteger(pileId) ||
            pileId < 0 ||
            pileId >= piles.value.length ||
            completedPileIds.value.includes(pileId)
        ) return

        activePileId.value = pileId
        progress.value = 0
        startedAt = performance.now()
        phase.value = 'counting'
    }

    /** Moves the counted pile to the right tray. */
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

    /** Advances the pile being counted. Called every animation frame. */
    function tick(now: number) {
        if (!running.value) return

        progress.value = Math.min(
            1,
            Math.max(0, (now - startedAt) / COUNT_DURATION_MS),
        )

        if (progress.value < 1) return

        phase.value = 'collect'
    }

    /** The player put the counted cash away: the count is done. */
    function complete(): boolean {
        if (!canFinish.value) return false

        finished.value = true

        return true
    }

    /** Hides the screen and forgets everything. Does not tell Lua. */
    function dismiss() {
        ui.close('cash-counter')
        payload.value = null
        reset()
    }

    /** Closes the screen and tells Lua: finished if the count was done, otherwise closed. */
    async function close() {
        const done = finished.value

        dismiss()

        try {
            await postNui(
                done ? NUI_CALLBACKS.cashFinish : NUI_CALLBACKS.cashClose,
            )
        } catch {
            // Lua releases the screen itself when the resource stops.
        }
    }

    return {
        payload,
        amount,
        settings,
        phase,
        piles,
        collected,
        started,
        progress,
        finished,
        activeAmount,
        running,
        canLoad,
        canCollect,
        allCollected,
        canFinish,
        countedAmount,
        completedPileIds,
        activePileId,
        open,
        loadPile,
        collectPile,
        tick,
        complete,
        dismiss,
        close,
    }
})