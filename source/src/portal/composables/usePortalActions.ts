import { isFiveMEnvironment, NUI_CALLBACKS, postNui } from '@/integrations/nui'
import type { NuiResponse } from '@/integrations/nui'
import type { PortalLocation, PortalLocationRequest } from '@/portal/portal.types'
import { usePortalStore } from '@/portal/stores/portal.store'
import { useUiStore } from '@/shared/stores/ui.store'

/** What the portal asks the game to do. */
export function usePortalActions() {
    const portal = usePortalStore()
    const ui = useUiStore()

    /** Closes the portal here first, then tells the game. */
    async function requestPortalClose(): Promise<void> {
        ui.close('marketplace')
        portal.resetInteractionState()

        if (!isFiveMEnvironment()) return

        try {
            await postNui<NuiResponse>(NUI_CALLBACKS.close)
        } catch (error) {
            console.error('[t1ger_moneywash] Failed to close the portal.', error)
        }
    }

    async function requestBusinessPurchase(location: PortalLocation): Promise<NuiResponse> {
        try {
            return await postNui<NuiResponse, PortalLocationRequest>(
                NUI_CALLBACKS.purchase,
                { businessType: location.businessType, locationId: location.locationId },
            )
        } catch (error) {
            console.error('[t1ger_moneywash] Failed to purchase the business.', error)

            return { success: false, reason: 'request_failed' }
        }
    }

    /** Sets a map waypoint to the business. Returns whether it worked. */
    async function requestBusinessWaypoint(location: PortalLocation): Promise<boolean> {
        try {
            const response = await postNui<NuiResponse, PortalLocationRequest>(
                NUI_CALLBACKS.waypoint,
                { businessType: location.businessType, locationId: location.locationId },
            )

            return response.success
        } catch (error) {
            console.error('[t1ger_moneywash] Failed to set the waypoint.', error)

            return false
        }
    }

    return { requestPortalClose, requestBusinessPurchase, requestBusinessWaypoint }
}