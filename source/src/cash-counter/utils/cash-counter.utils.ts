export const cashCounterImages = {
    machine: `${import.meta.env.BASE_URL}images/cash-counter/machine.png`,
    tray: `${import.meta.env.BASE_URL}images/cash-counter/tray.png`,
    loose: `${import.meta.env.BASE_URL}images/cash-counter/loose.png`,
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

export function cashPilePosition(index: number) {
    return {
        left: `${index % 2 === 0 ? 12 : 49}%`,
        bottom: `${20 + Math.floor(index / 2) * 4.5}%`,
        transform: `rotate(${index % 2 === 0 ? -2 : 2}deg)`,
        zIndex: index + 1,
    }
}