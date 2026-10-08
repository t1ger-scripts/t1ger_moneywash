import { onMounted, onUnmounted } from 'vue'
import { usePortalLifecycle } from '@/portal/composables/usePortalLifecycle'
import { usePortalActions } from '@/portal/composables/usePortalActions'
import { useUiStore } from '@/shared/stores/ui.store'
import { useCashCounterStore } from '@/features/cash-counter/cash-counter.store'
import type { CashCounterPayload } from '@/features/cash-counter/cash-counter.types'
import {
    isFiveMEnvironment,
    onNuiMessage,
    postNui,
} from '@/integrations/nui'
import { NUI_CALLBACKS, NUI_MESSAGES } from '@/integrations/nui'
export function useUiLifecycle() {
    usePortalLifecycle()
    const ui = useUiStore()
    const cash = useCashCounterStore()
    const portal = usePortalActions()
    let cleanup: Array<() => void> = []
    function keydown(event: KeyboardEvent) {
        if (event.key !== 'Escape' || event.defaultPrevented) return
        if (ui.activeScreen === 'marketplace') void portal.requestPortalClose()
        if (ui.activeScreen === 'cash-counter') void cash.close()
    }
    onMounted(async () => {
        cleanup = [
            onNuiMessage<CashCounterPayload>(NUI_MESSAGES.cashOpen, cash.open),
            onNuiMessage<void>(NUI_MESSAGES.cashClose, () =>
                ui.close('cash-counter'),
            ),
        ]
        window.addEventListener('keydown', keydown)
        if (isFiveMEnvironment()) {
            try {
                await postNui(NUI_CALLBACKS.uiReady)
            } catch (error) {
                console.error('[MoneyWash] UI readiness failed', error)
            }
        } else if (
            import.meta.env.DEV &&
            new URLSearchParams(location.search).get('screen') ===
                'cash-counter'
        ) {
            const { openCounterDemo } =
                await import('@/features/cash-counter/cash-counter.demo')
            openCounterDemo()
        }
    })
    onUnmounted(() => {
        cleanup.forEach((fn) => fn())
        window.removeEventListener('keydown', keydown)
    })
}
