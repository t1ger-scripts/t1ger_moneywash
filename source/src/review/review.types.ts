export interface ReviewReceipt {
    id: number
    units: number
    unitPrice: number
    totalAmount: number
    createdAt: number
}

export interface ReviewPayload {
    businessName: string
    currency: string
    locale: string
    maxReceipts: number
    receipts: ReviewReceipt[]
}