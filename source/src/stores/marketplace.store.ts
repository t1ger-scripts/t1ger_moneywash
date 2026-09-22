import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import type {
    BusinessLocation,
    BusinessTier,
    MarketplaceSnapshot,
} from '@/domain/marketplace'

export type PurchaseBlockReason =
    | 'alreadyOwnsBusiness'
    | 'insufficientFunds'
    | 'tierLocked'
    | 'locationUnavailable'

function tierContainsOwnedBusiness(
    snapshot: MarketplaceSnapshot,
    tier: BusinessTier,
): boolean {
    return snapshot.locations.some(
        (location) =>
            location.businessType === tier.businessType
            && location.ownership === 'ownedByPlayer',
    )
}

function isTierAccessible(
    snapshot: MarketplaceSnapshot,
    tier: BusinessTier,
): boolean {
    return tier.isUnlocked || tierContainsOwnedBusiness(snapshot, tier)
}

function findPreferredLocationId(
    snapshot: MarketplaceSnapshot,
    tierNumber: number | null,
): string | null {
    const tier = snapshot.tiers.find(
        (candidate) => candidate.tierNumber === tierNumber,
    )

    if (!tier) return null

    const tierLocations = snapshot.locations.filter(
        (location) =>
            location.businessType === tier.businessType,
    )

    const ownedLocation = tierLocations.find(
        (location) => location.ownership === 'ownedByPlayer',
    )

    return ownedLocation?.id ?? tierLocations[0]?.id ?? null
}

export const useMarketplaceStore = defineStore('marketplace', () => {
    const snapshot = ref<MarketplaceSnapshot | null>(null)
    const selectedTierNumber = ref<number | null>(null)
    const selectedLocationId = ref<string | null>(null)
    const purchaseDialogLocationId = ref<string | null>(null)
    const pendingPurchaseLocationId = ref<string | null>(null)
    const searchQuery = ref('')

    const profile = computed(() => snapshot.value?.profile ?? null)
    const tiers = computed(() => snapshot.value?.tiers ?? [])
    const locations = computed(() => snapshot.value?.locations ?? [])
    const currencySymbol = computed(
        () => snapshot.value?.currencySymbol ?? '$',
    )

    const selectedTier = computed(() =>
        tiers.value.find(
            (tier) => tier.tierNumber === selectedTierNumber.value,
        ) ?? null,
    )

    const selectedTierLocations = computed(() => {
        if (!selectedTier.value) return []

        return locations.value.filter(
            (location) =>
                location.businessType === selectedTier.value?.businessType,
        )
    })

    const filteredLocations = computed(() => {
        const normalizedQuery = searchQuery.value.trim().toLocaleLowerCase()

        if (!normalizedQuery) {
            return selectedTierLocations.value
        }

        return selectedTierLocations.value.filter((location) => {
            const searchableValues = [
                location.displayName,
                location.address.zone,
                location.address.street,
                location.address.crossingRoad,
            ]

            return searchableValues.some((value) =>
                value?.toLocaleLowerCase().includes(normalizedQuery),
            )
        })
    })

    const selectedLocation = computed(() =>
        locations.value.find(
            (location) => location.id === selectedLocationId.value,
        ) ?? null,
    )

    const purchaseDialogLocation = computed(() =>
        locations.value.find(
            (location) => location.id === purchaseDialogLocationId.value,
        ) ?? null,
    )

    const isPurchaseDialogOpen = computed(
        () => purchaseDialogLocation.value !== null,
    )

    const isPurchasePending = computed(
        () => pendingPurchaseLocationId.value !== null,
    )

    function getPurchaseBlockReason(
        location: BusinessLocation,
    ): PurchaseBlockReason | null {
        const currentSnapshot = snapshot.value

        if (!currentSnapshot || location.ownership !== 'available') {
            return 'locationUnavailable'
        }

        if (currentSnapshot.profile.ownsBusiness) {
            return 'alreadyOwnsBusiness'
        }

        const tier = currentSnapshot.tiers.find(
            (candidate) =>
                candidate.businessType === location.businessType,
        )

        if (!tier?.isUnlocked) {
            return 'tierLocked'
        }

        if (currentSnapshot.profile.bankBalance < location.price) {
            return 'insufficientFunds'
        }

        return null
    }

    function replaceSnapshot(nextSnapshot: MarketplaceSnapshot): void {
        snapshot.value = nextSnapshot

        const currentTier = nextSnapshot.tiers.find(
            (tier) => tier.tierNumber === selectedTierNumber.value,
        )

        if (
            !currentTier
            || !isTierAccessible(nextSnapshot, currentTier)
        ) {
            selectedTierNumber.value =
                nextSnapshot.tiers.find(
                    (tier) => isTierAccessible(nextSnapshot, tier),
                )?.tierNumber ?? null
        }

        const activeTier = nextSnapshot.tiers.find(
            (tier) =>
                tier.tierNumber === selectedTierNumber.value,
        )

        const selectedLocationStillExists =
            nextSnapshot.locations.some(
                (location) =>
                    location.id === selectedLocationId.value
                    && location.businessType === activeTier?.businessType,
            )

        if (!selectedLocationStillExists) {
            selectedLocationId.value = findPreferredLocationId(
                nextSnapshot,
                selectedTierNumber.value,
            )
        }

        const dialogLocation = nextSnapshot.locations.find(
            (location) =>
                location.id === purchaseDialogLocationId.value,
        )

        if (!dialogLocation || dialogLocation.ownership !== 'available') {
            purchaseDialogLocationId.value = null
        }

        if (
            pendingPurchaseLocationId.value
            && !nextSnapshot.locations.some(
                (location) =>
                    location.id === pendingPurchaseLocationId.value
                    && location.ownership === 'available',
            )
        ) {
            pendingPurchaseLocationId.value = null
        }
    }

    function selectTier(tierNumber: number): void {
        const currentSnapshot = snapshot.value
        if (!currentSnapshot) return

        const tier = currentSnapshot.tiers.find(
            (candidate) => candidate.tierNumber === tierNumber,
        )

        if (!tier || !isTierAccessible(currentSnapshot, tier)) return

        selectedTierNumber.value = tierNumber
        selectedLocationId.value = findPreferredLocationId(
            currentSnapshot,
            tierNumber,
        )
        purchaseDialogLocationId.value = null
        searchQuery.value = ''
    }

    function selectLocation(locationId: string | null): void {
        if (locationId === null) {
            selectedLocationId.value = null
            return
        }

        const location = locations.value.find(
            (candidate) => candidate.id === locationId,
        )

        if (!location) return
        if (location.businessType !== selectedTier.value?.businessType) return

        selectedLocationId.value = locationId
    }

    function setSearchQuery(value: string): void {
        searchQuery.value = value
    }

    function openPurchaseDialog(locationId: string): void {
        const location = locations.value.find(
            (candidate) => candidate.id === locationId,
        )

        if (!location) return
        if (getPurchaseBlockReason(location) !== null) return

        purchaseDialogLocationId.value = locationId
    }

    function closePurchaseDialog(): void {
        if (isPurchasePending.value) return

        purchaseDialogLocationId.value = null
    }

    function beginPurchase(locationId: string): boolean {
        if (pendingPurchaseLocationId.value !== null) return false

        const location = locations.value.find(
            (candidate) => candidate.id === locationId,
        )

        if (!location) return false
        if (getPurchaseBlockReason(location) !== null) return false

        pendingPurchaseLocationId.value = locationId
        return true
    }

    function finishPurchase(): void {
        pendingPurchaseLocationId.value = null
    }

    function resetInteractionState(): void {
        selectedLocationId.value = null
        purchaseDialogLocationId.value = null
        pendingPurchaseLocationId.value = null
        searchQuery.value = ''
    }

    return {
        snapshot,
        selectedTierNumber,
        selectedLocationId,
        purchaseDialogLocationId,
        pendingPurchaseLocationId,
        searchQuery,

        profile,
        tiers,
        locations,
        currencySymbol,
        selectedTier,
        selectedTierLocations,
        filteredLocations,
        selectedLocation,
        purchaseDialogLocation,
        isPurchaseDialogOpen,
        isPurchasePending,

        getPurchaseBlockReason,
        replaceSnapshot,
        selectTier,
        selectLocation,
        setSearchQuery,
        openPurchaseDialog,
        closePurchaseDialog,
        beginPurchase,
        finishPurchase,
        resetInteractionState,
    }
})