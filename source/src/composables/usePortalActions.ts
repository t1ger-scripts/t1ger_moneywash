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
        if (!isFiveMEnvironment()) {
            const currentSnapshot = marketplaceStore.snapshot

            if (!currentSnapshot) {
                return {
                    success: false,
                    reason: 'snapshotUnavailable',
                }
            }

            marketplaceStore.replaceSnapshot({
                ...currentSnapshot,

                profile: {
                    ...currentSnapshot.profile,
                    bankBalance: Math.max(
                        0,
                        currentSnapshot.profile.bankBalance - location.price,
                    ),
                    ownsBusiness: true,
                },

                tiers: currentSnapshot.tiers.map((tier) =>
                    tier.businessType === location.businessType
                        ? {
                            ...tier,
                            availableLocationCount: Math.max(
                                0,
                                tier.availableLocationCount - 1,
                            ),
                        }
                        : tier,
                ),

                locations: currentSnapshot.locations.map((candidate) =>
                    candidate.id === location.id
                        ? {
                            ...candidate,
                            ownedBusinessId:
                                candidate.ownedBusinessId ?? 1,
                            ownership: 'ownedByPlayer' as const,
                        }
                        : candidate,
                ),
            })

            return { success: true }
        }

        try {
            return await postNui<
                NuiResponse,
                PurchaseBusinessRequest
            >(
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
        if (!isFiveMEnvironment()) {
            return true
        }

        try {
            const response = await postNui<
                NuiResponse,
                SetBusinessWaypointRequest
            >(
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