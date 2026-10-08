const imageRoot =
    `${import.meta.env.BASE_URL}images/cash-counter/`

export const cashCounterImages = {
    scene: `${imageRoot}counter-scene.png`,
    bundle: `${imageRoot}cash-bundle.png`,
    stack: `${imageRoot}cash-stack.png`,
    note: `${imageRoot}cash-note.png`,
} as const

export function validAmount(
    amount: number,
    available: number,
): boolean {
    return Number.isSafeInteger(amount) &&
        amount > 0 &&
        amount <= available
}

export function splitCash(
    amount: number,
    stackCount: number,
): number[] {
    if (!Number.isSafeInteger(amount) || amount <= 0) return []

    const configured = Number.isFinite(stackCount)
        ? Math.floor(stackCount)
        : 1

    const count = Math.min(
        amount,
        Math.max(1, Math.min(20, configured)),
    )

    const base = Math.floor(amount / count)
    const remainder = amount % count

    return Array.from(
        { length: count },
        (_, index) => base + (index < remainder ? 1 : 0),
    )
}

export function trayPilePosition(
    slot: number,
    totalSlots: number,
) {
    const count = Math.max(1, totalSlots)
    const rise = Math.min(
        4.8,
        48 / Math.max(1, count - 1),
    )

    return {
        left: '16.425%',
        bottom: `${18 + slot * rise}%`,
        '--pile-turn': '0deg',
        '--pile-order': slot + 1,
        zIndex: slot + 1,
    }
}