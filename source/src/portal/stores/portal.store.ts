import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import type {
    PortalLocation,
    PortalSnapshot,
} from '@/portal/portal.types'

export type PurchaseBlockReason =
    | 'alreadyOwnsBusiness'
    | 'insufficientFunds'
    | 'tierLocked'
    | 'locationUnavailable'

/** A tier can be opened when it is unlocked, or when the player owns a business in it. */
function isTierAccessible(snapshot: PortalSnapshot, tierNumber: number): boolean {
    const tier = snapshot.tiers.find((candidate) => candidate.tierNumber === tierNumber)
    if (!tier) return false

    return tier.isUnlocked || snapshot.locations.some(
        (location) =>
            location.businessType === tier.businessType
            && location.ownership === 'ownedByPlayer',
    )
}

/** The tier to show first: the one with the player's business, else the first open one. */
function pickTier(snapshot: PortalSnapshot): number | null {
    const owned = snapshot.locations.find((location) => location.ownership === 'ownedByPlayer')
    const ownedTier = snapshot.tiers.find((tier) => tier.businessType === owned?.businessType)

    const tier = ownedTier
        ?? snapshot.tiers.find((candidate) => isTierAccessible(snapshot, candidate.tierNumber))

    return tier?.tierNumber ?? null
}

/** The location to select in a tier: the player's own, else the first one. */
function pickLocation(snapshot: PortalSnapshot, tierNumber: number | null): string | null {
    const tier = snapshot.tiers.find((candidate) => candidate.tierNumber === tierNumber)
    if (!tier) return null

    const inTier = snapshot.locations.filter(
        (location) => location.businessType === tier.businessType,
    )
    const owned = inTier.find((location) => location.ownership === 'ownedByPlayer')

    return (owned ?? inTier[0])?.key ?? null
}

export const usePortalStore = defineStore('portal', () => {
    const snapshot = ref<PortalSnapshot | null>(null)
    const selectedTierNumber = ref<number | null>(null)
    const selectedLocationKey = ref<string | null>(null)
    const purchaseDialogLocationKey = ref<string | null>(null)
    const pendingPurchaseLocationKey = ref<string | null>(null)
    const searchQuery = ref('')

    const profile = computed(() => snapshot.value?.profile ?? null)
    const tiers = computed(() => snapshot.value?.tiers ?? [])
    const locations = computed(() => snapshot.value?.locations ?? [])
    const currencySymbol = computed(() => snapshot.value?.settings.currencySymbol ?? '$')

    function findLocation(key: string | null): PortalLocation | null {
        return locations.value.find((location) => location.key === key) ?? null
    }

    const selectedTier = computed(() =>
        tiers.value.find((tier) => tier.tierNumber === selectedTierNumber.value) ?? null,
    )

    const selectedTierLocations = computed(() =>
        locations.value.filter(
            (location) => location.businessType === selectedTier.value?.businessType,
        ),
    )

    /** The selected tier's locations that match the search text. */
    const filteredLocations = computed(() => {
        const query = searchQuery.value.trim().toLocaleLowerCase()
        if (!query) return selectedTierLocations.value

        return selectedTierLocations.value.filter((location) =>
            [
                location.displayName,
                location.address.zone,
                location.address.street,
                location.address.crossingRoad,
            ].some((text) => text?.toLocaleLowerCase().includes(query)),
        )
    })

    const selectedLocation = computed(() => findLocation(selectedLocationKey.value))
    const purchaseDialogLocation = computed(() => findLocation(purchaseDialogLocationKey.value))
    const isPurchaseDialogOpen = computed(() => purchaseDialogLocation.value !== null)
    const isPurchasePending = computed(() => pendingPurchaseLocationKey.value !== null)

    /** Why the player can't buy this location, or null when they can. */
    function getPurchaseBlockReason(location: PortalLocation): PurchaseBlockReason | null {
        const current = snapshot.value

        if (!current || location.ownership !== 'available') return 'locationUnavailable'
        if (current.profile.ownsBusiness) return 'alreadyOwnsBusiness'

        const tier = current.tiers.find((candidate) => candidate.businessType === location.businessType)
        if (!tier?.isUnlocked) return 'tierLocked'

        if (current.profile.bankBalance < location.price) return 'insufficientFunds'

        return null
    }

    /** Takes new data and keeps the selection when it is still valid. */
    function replaceSnapshot(next: PortalSnapshot): void {
        snapshot.value = next

        if (!isTierAccessible(next, selectedTierNumber.value ?? -1)) {
            selectedTierNumber.value = pickTier(next)
        }

        const tier = next.tiers.find((candidate) => candidate.tierNumber === selectedTierNumber.value)
        const selectionStillValid = next.locations.some(
            (location) =>
                location.key === selectedLocationKey.value
                && location.businessType === tier?.businessType,
        )

        if (!selectionStillValid) {
            selectedLocationKey.value = pickLocation(next, selectedTierNumber.value)
        }

        const isAvailable = (key: string | null) =>
            next.locations.some((location) => location.key === key && location.ownership === 'available')

        if (!isAvailable(purchaseDialogLocationKey.value)) purchaseDialogLocationKey.value = null
        if (!isAvailable(pendingPurchaseLocationKey.value)) pendingPurchaseLocationKey.value = null
    }

    function selectTier(tierNumber: number): void {
        if (!snapshot.value || !isTierAccessible(snapshot.value, tierNumber)) return

        selectedTierNumber.value = tierNumber
        selectedLocationKey.value = pickLocation(snapshot.value, tierNumber)
        purchaseDialogLocationKey.value = null
        searchQuery.value = ''
    }

    function selectLocation(key: string | null): void {
        if (key === null) {
            selectedLocationKey.value = null
            return
        }

        const location = findLocation(key)
        if (!location || location.businessType !== selectedTier.value?.businessType) return

        selectedLocationKey.value = key
    }

    function setSearchQuery(value: string): void {
        searchQuery.value = value
    }

    function openPurchaseDialog(key: string): void {
        const location = findLocation(key)
        if (!location || getPurchaseBlockReason(location) !== null) return

        purchaseDialogLocationKey.value = key
    }

    function closePurchaseDialog(): void {
        if (isPurchasePending.value) return

        purchaseDialogLocationKey.value = null
    }

    /** Marks a purchase as running. Returns false when one is already running or the location can't be bought. */
    function beginPurchase(key: string): boolean {
        if (isPurchasePending.value) return false

        const location = findLocation(key)
        if (!location || getPurchaseBlockReason(location) !== null) return false

        pendingPurchaseLocationKey.value = key
        return true
    }

    function finishPurchase(): void {
        pendingPurchaseLocationKey.value = null
    }

    /** Clears the selection, search and purchase state (the data stays). */
    function resetInteractionState(): void {
        selectedTierNumber.value = null
        selectedLocationKey.value = null
        purchaseDialogLocationKey.value = null
        pendingPurchaseLocationKey.value = null
        searchQuery.value = ''
    }

    return {
        selectedTierNumber,
        selectedLocationKey,
        purchaseDialogLocationKey,
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