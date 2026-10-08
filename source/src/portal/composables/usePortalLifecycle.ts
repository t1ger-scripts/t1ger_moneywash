import { onMounted, onUnmounted } from 'vue'

import { createMarketplaceSnapshot } from '@/portal/portal.model'
import { installLocaleMessages } from '@/integrations/localization/i18n'
import { onNuiMessage } from '@/integrations/nui/nuiClient'
import { NUI_MESSAGES } from '@/integrations/nui/nuiEvents'
import type { PortalBootstrapPayload } from '@/integrations/nui/nui.types'
import { applyTheme } from '@/portal/theme/applyTheme'
import { usePortalStore } from '@/portal/stores/portal.store'
import { useUiStore } from '@/shared/stores/ui.store'

export function usePortalLifecycle(): void {
    const portalStore = usePortalStore()
    const ui = useUiStore()

    const unsubscribeFunctions: Array<() => void> = []

    function applyBootstrap(
        payload: PortalBootstrapPayload,
        resetInteractionState: boolean,
    ): void {
        installLocaleMessages(
            payload.localization.locale,
            payload.localization.messages,
        )

        applyTheme(payload.settings.theme)

        if (resetInteractionState) {
            portalStore.resetInteractionState()
        }

        portalStore.replaceSnapshot(createMarketplaceSnapshot(payload))

        if (resetInteractionState) ui.open('marketplace')
    }

    function openPortal(payload: PortalBootstrapPayload): void {
        applyBootstrap(payload, true)
    }

    function refreshPortal(payload: PortalBootstrapPayload): void {
        applyBootstrap(payload, false)
    }

    function closePortal(): void {
        ui.close('marketplace')
        portalStore.resetInteractionState()
    }

    onMounted(() => {
        unsubscribeFunctions.push(
            onNuiMessage<PortalBootstrapPayload>(NUI_MESSAGES.open, openPortal),
        )

        unsubscribeFunctions.push(
            onNuiMessage<PortalBootstrapPayload>(
                NUI_MESSAGES.refresh,
                refreshPortal,
            ),
        )

        unsubscribeFunctions.push(
            onNuiMessage<void>(NUI_MESSAGES.close, closePortal),
        )
    })

    onUnmounted(() => {
        for (const unsubscribe of unsubscribeFunctions) {
            unsubscribe()
        }
    })
}
