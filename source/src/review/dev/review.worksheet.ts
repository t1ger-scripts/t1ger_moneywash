import type {
    ReviewEntry,
    ReviewReceipt,
} from '../review.types'

function changeNumber(
    value: number,
    percentage: number,
    minimum: number,
): number {
    const difference = Math.max(1, Math.round(value * percentage))

    const candidate = value + (
        Math.random() < 0.5 ? -difference : difference
    )

    return candidate >= minimum
        ? candidate
        : value + difference
}

export function createReviewWorksheet(
    receipts: ReviewReceipt[],
): ReviewEntry[] {
    const entries: ReviewEntry[] = receipts.map((receipt) => {
        const entry: ReviewEntry = {
            id: receipt.id,
            createdAt: receipt.createdAt,
            units: receipt.units,
            totalAmount: receipt.totalAmount,
            matchedReceiptId: null,
        }

        // Every row gets exactly one fault.
        if (Math.random() < 0.5) {
            entry.units = changeNumber(receipt.units, 0.15, 1)
        } else {
            entry.totalAmount = changeNumber(
                receipt.totalAmount,
                0.1,
                0,
            )
        }

        return entry
    })

    for (let index = entries.length - 1; index > 0; index--) {
        const target = Math.floor(Math.random() * (index + 1))
        const entry = entries[index]!

        entries[index] = entries[target]!
        entries[target] = entry
    }

    return entries
}