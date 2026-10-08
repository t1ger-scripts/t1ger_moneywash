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

export function cashPilePosition(index: number, totalSlots = 10) {
    const count = Math.max(1, Math.floor(totalSlots))
    const slot = Math.max(0, Math.min(count - 1, index))

    const spacing = count > 1
        ? Math.min(12, 68 / (count - 1))
        : 0

    const offsets = [-1.8, 1.2, -0.6, 1.8, 0]
    const turns = [-1.2, 0.8, -0.4, 1.1, -0.7]
    const variation = slot % offsets.length

    return {
        left: `${16.425 + (offsets[variation] ?? 0)}%`,
        bottom: `${3 + slot * spacing}%`,
        '--pile-turn': `${turns[variation] ?? 0}deg`,
        '--pile-order': count - slot,
        zIndex: count - slot,
    }
}