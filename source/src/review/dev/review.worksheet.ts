import type {
    ReviewEntry,
    ReviewReceipt,
    ReviewGrade,
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

export function gradeReviewWorksheet(
    entries: ReviewEntry[],
    receipts: ReviewReceipt[],
    skillImpact: number,
): ReviewGrade {
    const originals = new Map(
        receipts.map((receipt) => [receipt.id, receipt]),
    )

    function matches(
        value: number | string,
        expected: number,
    ): boolean {
        const number = typeof value === 'string' && value.trim() === ''
            ? NaN
            : Number(value)

        return Number.isSafeInteger(number) && number === expected
    }

    const mistakes = entries.reduce((total, entry) => {
        const original = originals.get(entry.id)

        const correct = original &&
            entry.matchedReceiptId === original.id &&
            entry.createdAt === original.createdAt &&
            matches(entry.units, original.units) &&
            matches(entry.totalAmount, original.totalAmount)

        // A row contributes at most one mistake.
        return total + (correct ? 0 : 1)
    }, 0)

    const impact = Number.isFinite(skillImpact)
        ? Math.max(0, Math.min(100, skillImpact))
        : 30

    const accuracy = entries.length === 0
        ? 1
        : 1 - mistakes / entries.length

    return {
        mistakes,
        quality: Math.max(1 - impact / 100, accuracy),
    }
}