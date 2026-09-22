import type { LocaleMessages } from '@/integrations/localization/localization.types'
import type { PortalThemeConfig } from '@/integrations/theme/theme.types'

export interface PortalCoordinates {
    x: number
    y: number
    z: number
}

export interface PortalAddress {
    street: string | null
    crossingRoad: string | null
    zone: string | null
}

export type PortalLocationOwnership =
    | 'available'
    | 'ownedByPlayer'

export interface PortalBusinessLocation {
    key: string
    locationId: number
    ownedBusinessId: number | null
    businessType: string
    displayName: string
    imageFileName: string | null
    price: number
    ownership: PortalLocationOwnership
    coordinates: PortalCoordinates
    address: PortalAddress
}

export interface PortalBusinessTier {
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

export interface PortalInvestorProgress {
    points: number
    rank: string
    currentRankPoints: number
    nextRankPoints: number | null
    percentage: number
}

export interface PortalPlayerProfile {
    characterName: string
    bankBalance: number
    ownsBusiness: boolean
    investorProgress: PortalInvestorProgress
}

export interface PortalRuntimeSettings {
    currencySymbol: string
    theme: PortalThemeConfig
}

export interface PortalLocalization {
    locale: string
    messages: LocaleMessages
}

export interface PortalBootstrapPayload {
    profile: PortalPlayerProfile
    tiers: PortalBusinessTier[]
    locations: PortalBusinessLocation[]
    settings: PortalRuntimeSettings
    localization: PortalLocalization
}

export interface PurchaseBusinessRequest {
    businessType: string
    locationId: number
}

export interface SetBusinessWaypointRequest {
    businessType: string
    locationId: number
}

export interface NuiResponse<TData = undefined> {
    success: boolean
    reason?: string
    data?: TData
}

export interface NuiMessage<TData = unknown> {
    action: string
    data?: TData
}