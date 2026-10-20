import type { ReviewPayload } from '../review.types'

export function createReviewPreview(count = 24): ReviewPayload {
    const total = Number.isFinite(count)
        ? Math.max(0, Math.min(100, Math.floor(count)))
        : 24

    const deliveredAt = Math.floor(
        Date.UTC(2026, 9, 20, 10) / 1000,
    )

    return {
        businessName: 'Vespucci Trading Co.',
        currency: '$',
        locale: 'en-US',
        maxReceipts: 12,
        suspicion: 68,
        expectedRevenue: 50000,
        launderDollarsPerUnit: 500,
        settings: {
            maxReduction: 15,
            cyclesForMax: 5,
            minReduction: 3,
            feePercent: 20,
            skillImpact: 30,
        },
        receipts: Array.from({ length: total }, (_, index) => {
            const units = 20 + (index % 5) * 10
            const unitPrice = 125

            return {
                id: 1048 + index,
                units,
                unitPrice,
                totalAmount: units * unitPrice,
                createdAt: deliveredAt - index * 86400,
            }
        }),
    }
}