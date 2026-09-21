import { onMounted, onUnmounted } from 'vue'

import { createMarketplaceSnapshot } from '@/domain/marketplace'
import { installLocaleMessages } from '@/integrations/localization/i18n'
import { isFiveMEnvironment, onNuiMessage, postNui } from '@/integrations/nui/nuiClient'
import { NUI_CALLBACKS, NUI_MESSAGES } from '@/integrations/nui/nuiEvents'
import type {
    NuiResponse,
    PortalBootstrapPayload,
} from '@/integrations/nui/nui.types'
import { applyTheme } from '@/integrations/theme/applyTheme'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { usePortalStore } from '@/stores/portal.store'

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

        marketplaceStore.replaceSnapshot(
            createMarketplaceSnapshot(payload),
        )

        portalStore.show()
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

    async function notifyFiveMReady(): Promise<void> {
        try {
            const response = await postNui<
                NuiResponse<PortalBootstrapPayload>
            >(NUI_CALLBACKS.ready)

            if (response.success && response.data) {
                openPortal(response.data)
            }
        } catch (error) {
            console.error(
                '[t1ger_moneywash] Failed to notify FiveM that the portal is ready.',
                error,
            )
        }
    }

    async function requestClose(): Promise<void> {
        if (!isFiveMEnvironment()) return

        closePortal()

        try {
            await postNui<NuiResponse>(NUI_CALLBACKS.close)
        } catch (error) {
            console.error(
                '[t1ger_moneywash] Failed to close the portal cleanly.',
                error,
            )
        }
    }

    function handleKeydown(event: KeyboardEvent): void {
        if (event.key !== 'Escape') return
        if (!portalStore.isVisible) return

        void requestClose()
    }

    onMounted(async () => {
        unsubscribeFunctions.push(
            onNuiMessage<PortalBootstrapPayload>(
                NUI_MESSAGES.open,
                openPortal,
            ),
        )

        unsubscribeFunctions.push(
            onNuiMessage<PortalBootstrapPayload>(
                NUI_MESSAGES.refresh,
                refreshPortal,
            ),
        )

        unsubscribeFunctions.push(
            onNuiMessage<void>(
                NUI_MESSAGES.close,
                closePortal,
            ),
        )

        window.addEventListener('keydown', handleKeydown)

        if (import.meta.env.DEV && !isFiveMEnvironment()) {
            const { mockPortalBootstrap } = await import(
                '@/development/mockPortalBootstrap'
            )

            openPortal(mockPortalBootstrap)
            return
        }

        if (isFiveMEnvironment()) {
            await notifyFiveMReady()
        }
    })

    onUnmounted(() => {
        for (const unsubscribe of unsubscribeFunctions) {
            unsubscribe()
        }

        window.removeEventListener('keydown', handleKeydown)
    })
}