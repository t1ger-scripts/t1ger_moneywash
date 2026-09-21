import type { PortalBootstrapPayload } from '@/integrations/nui/nui.types'

export type BusinessOwnership =
    | 'available'
    | 'ownedByPlayer'

export interface BusinessCoordinates {
    x: number
    y: number
    z: number
}

export interface BusinessAddress {
    street: string | null
    crossingRoad: string | null
    zone: string | null
}

export interface BusinessLocation {
    id: string
    locationId: number
    ownedBusinessId: number | null
    businessType: string
    displayName: string
    imageFileName: string | null
    price: number
    ownership: BusinessOwnership
    coordinates: BusinessCoordinates
    address: BusinessAddress
}

export interface BusinessTier {
    tierNumber: number
    businessType: string
    displayName: string
    requiredInvestorScore: number
    purchasePrice: number
    projectedRevenue: number
    operatingFeePercentage: number
    isUnlocked: boolean
    availableLocationCount: number
    totalLocationCount: number
}

export interface InvestorProgress {
    points: number
    rank: string
    currentRankPoints: number
    nextRankPoints: number | null
    percentage: number
}

export interface PlayerProfile {
    characterName: string
    bankBalance: number
    ownsBusiness: boolean
    investorProgress: InvestorProgress
}

export interface MarketplaceSnapshot {
    profile: PlayerProfile
    tiers: BusinessTier[]
    locations: BusinessLocation[]
    currencySymbol: string
}

function clampPercentage(value: number): number {
    return Math.min(100, Math.max(0, value))
}

export function createMarketplaceSnapshot(
    payload: PortalBootstrapPayload,
): MarketplaceSnapshot {
    const tiers = payload.tiers
        .map<BusinessTier>((tier) => ({
            tierNumber: tier.tierNumber,
            businessType: tier.businessType,
            displayName: tier.displayName,
            requiredInvestorScore: tier.requiredInvestorScore,
            purchasePrice: tier.purchasePrice,
            projectedRevenue: tier.projectedRevenue,
            operatingFeePercentage: tier.operatingFeePercentage,
            isUnlocked: tier.isUnlocked,
            availableLocationCount: tier.availableLocationCount,
            totalLocationCount: tier.totalLocationCount,
        }))
        .sort((firstTier, secondTier) =>
            firstTier.tierNumber - secondTier.tierNumber,
        )

    const locations = payload.locations
        .map<BusinessLocation>((location) => ({
            id: location.key,
            locationId: location.locationId,
            ownedBusinessId: location.ownedBusinessId,
            businessType: location.businessType,
            displayName: location.displayName,
            imageFileName: location.imageFileName,
            price: location.price,
            ownership: location.ownership,
            coordinates: location.coordinates,
            address: location.address,
        }))
        .sort((firstLocation, secondLocation) =>
            firstLocation.locationId - secondLocation.locationId,
        )

    return {
        profile: {
            characterName: payload.profile.characterName,
            bankBalance: payload.profile.bankBalance,
            ownsBusiness: payload.profile.ownsBusiness,
            investorProgress: {
                ...payload.profile.investorProgress,
                percentage: clampPercentage(
                    payload.profile.investorProgress.percentage,
                ),
            },
        },
        tiers,
        locations,
        currencySymbol: payload.settings.currencySymbol,
    }
}