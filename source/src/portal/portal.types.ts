import type { LocaleMessages } from '@/integrations/i18n'
import type { PortalThemeConfig } from './theme/theme.types'

export interface PortalCoordinates {
    x: number
    y: number
    z: number
}

/** Filled in by the client; a part the game has no name for is missing. */
export interface PortalAddress {
    street?: string
    crossingRoad?: string
    zone?: string
}

export type LocationOwnership = 'available' | 'ownedByPlayer'

export interface PortalLocation {
    /** "<businessType>:<locationId>", unique across all business types. */
    key: string
    locationId: number
    ownedBusinessId?: number
    businessType: string
    displayName: string
    imageFileName?: string
    price: number
    ownership: LocationOwnership
    coordinates: PortalCoordinates
    address: PortalAddress
}

export interface PortalTier {
    tierNumber: number
    businessType: string
    displayName: string
    requiredInvestorScore: number
    projectedRevenue: number
    isUnlocked: boolean
    availableLocationCount: number
    totalLocationCount: number
}

export interface PortalInvestorProgress {
    points: number
    rank: string
    currentRankPoints: number
    nextRankPoints?: number
    percentage: number
}

export interface PortalProfile {
    characterName: string
    bankBalance: number
    ownsBusiness: boolean
    investorProgress: PortalInvestorProgress
}

export interface PortalSettings {
    currencySymbol: string
    theme: PortalThemeConfig
}

/** Everything the portal shows. Sent when it opens and again on every refresh. */
export interface PortalSnapshot {
    profile: PortalProfile
    tiers: PortalTier[]
    locations: PortalLocation[]
    settings: PortalSettings
}

/** The first message also carries the UI language. */
export interface PortalOpenPayload extends PortalSnapshot {
    locale: string
    messages: LocaleMessages
}

/** Sent with a purchase or waypoint request. */
export interface PortalLocationRequest {
    businessType: string
    locationId: number
}