import { isFiveMEnvironment, postNui } from '@/integrations/nui/nuiClient'
import { NUI_CALLBACKS } from '@/integrations/nui/nuiEvents'
import type { NuiResponse } from '@/integrations/nui/nui.types'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { usePortalStore } from '@/stores/portal.store'

export function usePortalActions() {
    const marketplaceStore = useMarketplaceStore()
    const portalStore = usePortalStore()

    async function requestPortalClose(): Promise<void> {
        portalStore.hide()
        marketplaceStore.resetInteractionState()

        if (!isFiveMEnvironment()) return

        try {
            await postNui<NuiResponse>(NUI_CALLBACKS.close)
        } catch (error) {
            console.error(
                '[t1ger_moneywash] Failed to close the portal cleanly.',
                error,
            )
        }
    }

    return {
        requestPortalClose,
    }
}