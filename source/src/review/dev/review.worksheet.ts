import type {
    ReviewEntry,
    ReviewReceipt,
} from '../review.types'

export function createReviewWorksheet(
    receipts: ReviewReceipt[],
    faultPercent: number,
): ReviewEntry[] {
    const entries = receipts.map((receipt) => ({
        id: receipt.id,
        units: receipt.units,
        totalAmount: receipt.totalAmount,
        createdAt: receipt.createdAt,
        matchedReceiptId: null,
    }))

    for (let index = entries.length - 1; index > 0; index--) {
        const target = Math.floor(Math.random() * (index + 1))
        const entry = entries[index]!

        entries[index] = entries[target]!
        entries[target] = entry
    }

    const percentage = Number.isFinite(faultPercent)
        ? Math.max(0, Math.min(100, faultPercent))
        : 0

    // Always leave at least one clean row.
    const faultCount = Math.min(
        Math.max(0, entries.length - 1),
        Math.round(entries.length * percentage / 100),
    )

    for (const entry of entries.slice(0, faultCount)) {
        if (Math.random() < 0.5) {
            entry.units += Math.max(1, Math.round(entry.units * 0.15))
        } else {
            entry.totalAmount += Math.max(
                1,
                Math.round(entry.totalAmount * 0.1),
            )
        }
    }

    return entries
}