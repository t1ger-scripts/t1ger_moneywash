import { onMounted, onUnmounted } from 'vue'

import { installLocaleMessages } from '@/integrations/i18n'
import { NUI_MESSAGES, onNuiMessage } from '@/integrations/nui'
import type { PortalOpenPayload, PortalSnapshot } from '@/portal/portal.types'
import { usePortalStore } from '@/portal/stores/portal.store'
import { applyTheme } from '@/portal/theme/applyTheme'
import { useUiStore } from '@/shared/stores/ui.store'

/** Listens for the portal's messages from the game. */
export function usePortalLifecycle(): void {
    const portal = usePortalStore()
    const ui = useUiStore()

    let unsubscribe: Array<() => void> = []

    function open(payload: PortalOpenPayload): void {
        installLocaleMessages(payload.locale, payload.messages)
        applyTheme(payload.settings.theme)

        portal.resetInteractionState()
        portal.replaceSnapshot(payload)

        ui.open('marketplace')
    }

    /** New data while the portal is open: the selection stays. */
    function refresh(payload: PortalSnapshot): void {
        portal.replaceSnapshot(payload)
    }

    function close(): void {
        ui.close('marketplace')
        portal.resetInteractionState()
    }

    onMounted(() => {
        unsubscribe = [
            onNuiMessage<PortalOpenPayload>(NUI_MESSAGES.open, open),
            onNuiMessage<PortalSnapshot>(NUI_MESSAGES.refresh, refresh),
            onNuiMessage<void>(NUI_MESSAGES.close, close),
        ]
    })

    onUnmounted(() => unsubscribe.forEach((stop) => stop()))
}