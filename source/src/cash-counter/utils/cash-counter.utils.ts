export const cashCounterImages = {
    pile: `${import.meta.env.BASE_URL}images/cash-counter/pile.png`,
    bill: `${import.meta.env.BASE_URL}images/cash-counter/bill.png`,
}

export function validAmount(amount: number, available: number): boolean {
    return Number.isSafeInteger(amount) && amount > 0 && amount <= available
}

export function splitCash(amount: number, stackCount: number): number[] {
    if (!Number.isSafeInteger(amount) || amount <= 0) return []

    const configured = Number.isFinite(stackCount)
        ? Math.floor(stackCount)
        : 1

    const count = Math.min(amount, Math.max(1, Math.min(20, configured)))
    const base = Math.floor(amount / count)
    const remainder = amount % count

    return Array.from(
        { length: count },
        (_, index) => base + (index < remainder ? 1 : 0),
    )
}