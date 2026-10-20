export interface ReviewReceipt {
    id: number
    units: number
    unitPrice: number
    totalAmount: number
    createdAt: number
}

export interface ReviewSettings {
    maxReduction: number
    cyclesForMax: number
    minReduction: number
    feePercent: number
    faultPercent: number
}

export interface ReviewPayload {
    businessName: string
    currency: string
    locale: string
    maxReceipts: number
    suspicion: number
    expectedRevenue: number
    launderDollarsPerUnit: number
    settings: ReviewSettings
    receipts: ReviewReceipt[]
}

export interface ReviewEntry {
    id: number
    units: number | string
    totalAmount: number | string
    createdAt: number
    matchedReceiptId: number | null
}