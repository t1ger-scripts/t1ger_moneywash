import type { BusinessLocation } from '@/domain/marketplace'
import {
    isFiveMEnvironment,
    postNui,
} from '@/integrations/nui/nuiClient'
import { NUI_CALLBACKS } from '@/integrations/nui/nuiEvents'
import type {
    NuiResponse,
    PurchaseBusinessRequest,
    SetBusinessWaypointRequest,
} from '@/integrations/nui/nui.types'
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

    async function requestBusinessPurchase(
        location: BusinessLocation,
    ): Promise<NuiResponse> {
        try {
            return await postNui<NuiResponse, PurchaseBusinessRequest>(
                NUI_CALLBACKS.purchaseBusiness,
                {
                    businessType: location.businessType,
                    locationId: location.locationId,
                },
            )
        } catch (error) {
            console.error(
                '[t1ger_moneywash] Failed to purchase the business.',
                error,
            )

            return {
                success: false,
                reason: 'requestFailed',
            }
        }
    }

    async function requestBusinessWaypoint(
        location: BusinessLocation,
    ): Promise<boolean> {
        try {
            const response = await postNui<NuiResponse, SetBusinessWaypointRequest>(
                NUI_CALLBACKS.setBusinessWaypoint,
                {
                    businessType: location.businessType,
                    locationId: location.locationId,
                },
            )

            return response.success
        } catch (error) {
            console.error(
                '[t1ger_moneywash] Failed to set the business waypoint.',
                error,
            )

            return false
        }
    }

    return {
        requestPortalClose,
        requestBusinessPurchase,
        requestBusinessWaypoint,
    }
}