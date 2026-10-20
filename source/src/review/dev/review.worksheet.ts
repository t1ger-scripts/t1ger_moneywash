import type {
    ReviewEntry,
    ReviewReceipt,
} from '../review.types'
import { formatReviewDateInput } from '../utils/review.utils'

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
            deliveryDate: formatReviewDateInput(receipt.createdAt),
            units: receipt.units,
            totalAmount: receipt.totalAmount,
            matchedReceiptId: null,
        }

        // Each row receives exactly one of the three fault types.
        const fault = Math.floor(Math.random() * 3)

        if (fault === 0) {
            const days = 1 + Math.floor(Math.random() * 3)
            const direction = Math.random() < 0.5 ? -1 : 1

            entry.deliveryDate = formatReviewDateInput(
                receipt.createdAt + direction * days * 86400,
            )
        } else if (fault === 1) {
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

    // Shuffle the rows without modifying the original receipts.
    for (let index = entries.length - 1; index > 0; index--) {
        const target = Math.floor(Math.random() * (index + 1))
        const entry = entries[index]!

        entries[index] = entries[target]!
        entries[target] = entry
    }

    return entries
}