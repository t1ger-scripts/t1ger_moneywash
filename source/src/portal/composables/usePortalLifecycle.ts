import { onMounted, onUnmounted } from 'vue'

import { createMarketplaceSnapshot } from '@/portal/marketplace'
import { installLocaleMessages } from '@/integrations/localization/i18n'
import { onNuiMessage } from '@/integrations/nui/nuiClient'
import { NUI_MESSAGES } from '@/integrations/nui/nuiEvents'
import type { PortalBootstrapPayload } from '@/integrations/nui/nui.types'
import { applyTheme } from '@/portal/theme/applyTheme'
import { useMarketplaceStore } from '@/portal/stores/marketplace.store'
import { usePortalStore } from '@/portal/stores/portal.store'

export function usePortalLifecycle(): void {
    const marketplaceStore = useMarketplaceStore()
    const portalStore = usePortalStore()

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
            marketplaceStore.resetInteractionState()
        }

        marketplaceStore.replaceSnapshot(createMarketplaceSnapshot(payload))

        if (resetInteractionState) portalStore.show()
    }

    function openPortal(payload: PortalBootstrapPayload): void {
        applyBootstrap(payload, true)
    }

    function refreshPortal(payload: PortalBootstrapPayload): void {
        applyBootstrap(payload, false)
    }

    function closePortal(): void {
        portalStore.hide()
        marketplaceStore.resetInteractionState()
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
