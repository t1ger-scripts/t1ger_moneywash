export interface Coordinates {
  x: number
  y: number
  z: number
  heading: number
}

export interface BusinessTier {
  tier: number
  type: string
  label: string
  weight: number
  requiredPoints: number
  price: number
  npc?: string
  expectedRevenue: number
  launderFee: number
  unlocked?: boolean
  alreadyOwns?: boolean
  hasCapacity?: boolean
  availableCount?: number
}

export type ListingStatus = 'available' | 'active' | 'acquired'

export interface BusinessLocation {
  uid: string
  id: number
  businessId?: number
  type: string
  brand: string
  coords: Coordinates
  street?: string
  crossingStreet?: string
  zone?: string
  price?: number
  status?: ListingStatus
}

export interface LocationView extends BusinessLocation {
  tier: BusinessTier
  effectivePrice: number
  zone: string
  locked: boolean
  status: ListingStatus
}

export interface ReputationLevel {
  points: number
  label: string
}

export interface BrowserProfile {
  characterName: string
  balance: number
  reputation: number
  reputationLabel: string
  portfolioWeight: number
  portfolioLimit: number
}

export interface BrowserTheme {
  AccentColor?: string
  AccentHoverColor?: string
  AccentDarkColor?: string
  AccentSoftColor?: string

  BodyColor?: string
  PanelColor?: string
  PanelAltColor?: string
  CardColor?: string

  BorderColor?: string
  BorderSoftColor?: string

  TextColor?: string
  MutedTextColor?: string

  SuccessColor?: string
  WarningColor?: string
  DangerColor?: string
}

export interface BrowserSnapshot {
  profile: BrowserProfile
  tiers: BusinessTier[]
  locations: BusinessLocation[]
  reputationLevels: ReputationLevel[]

  settings: {
    currency: string
    transferDistance: number
    theme: BrowserTheme
  }

  locales?: Record<string, unknown>
}