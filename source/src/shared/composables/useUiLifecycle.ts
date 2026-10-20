import { onMounted, onUnmounted } from 'vue'
import { usePortalLifecycle } from '@/portal/composables/usePortalLifecycle'
import { usePortalActions } from '@/portal/composables/usePortalActions'
import { useUiStore } from '@/shared/stores/ui.store'
import { useCashCounterStore } from '@/cash-counter/stores/cash-counter.store'
import type { CashCounterPayload } from '@/cash-counter/cash-counter.types'
import { useRaidStore } from '@/raid/stores/raid.store'
import type { RaidPayload } from '@/raid/raid.types'
import { useReviewStore } from '@/review/stores/review.store'
import { isFiveMEnvironment, onNuiMessage, postNui, NUI_CALLBACKS, NUI_MESSAGES } from '@/integrations/nui'

export function useUiLifecycle() {
    usePortalLifecycle()

    const ui = useUiStore()
    const cash = useCashCounterStore()
    const raid = useRaidStore()
    const review = useReviewStore()
    const portal = usePortalActions()
    let cleanup: Array<() => void> = []

    function keydown(event: KeyboardEvent) {
        if (event.key !== 'Escape' || event.defaultPrevented) return

        if (ui.activeScreen === 'marketplace') {
            void portal.requestPortalClose()
        }

        if (ui.activeScreen === 'cash-counter') {
            void cash.close()
        }

        if (ui.activeScreen === 'raid') {
            void raid.close()
        }

        if (ui.activeScreen === 'review') {
            review.dismiss()
        }
    }

    onMounted(async () => {
        cleanup = [
            onNuiMessage<CashCounterPayload>(
                NUI_MESSAGES.cashOpen,
                cash.open,
            ),
            onNuiMessage<void>(
                NUI_MESSAGES.cashClose,
                cash.dismiss,
            ),
            onNuiMessage<RaidPayload>(
                NUI_MESSAGES.raidOpen,
                raid.open,
            ),
            onNuiMessage<void>(
                NUI_MESSAGES.raidClose,
                raid.dismiss,
            ),
        ]

        window.addEventListener('keydown', keydown)

        if (isFiveMEnvironment()) {
            try {
                await postNui(NUI_CALLBACKS.uiReady)
            } catch (error) {
                console.error('[MoneyWash] UI readiness failed', error)
            }
        }
    })

    onUnmounted(() => {
        cleanup.forEach((unsubscribe) => unsubscribe())
        window.removeEventListener('keydown', keydown)
    })
}