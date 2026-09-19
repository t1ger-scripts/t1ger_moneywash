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
  npc: string
  expectedRevenue: number
  launderFee: number
}

export interface BusinessLocation {
  uid: string
  id: number
  type: string
  brand: string
  coords: Coordinates
  street?: string
  crossingStreet?: string
  price?: number
}

export type ListingStatus = 'available' | 'active' | 'acquired'

export interface LocationView extends BusinessLocation {
  tier: BusinessTier
  effectivePrice: number
  zone: string
  locked: boolean
  status: ListingStatus
}