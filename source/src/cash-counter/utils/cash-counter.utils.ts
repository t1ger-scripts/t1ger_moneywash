const imageRoot = `${import.meta.env.BASE_URL}images/cash-counter/`

/** Counting time per pile in ms. */
export const COUNT_DURATION_MS = 800

export const cashCounterImages = {
    scene: `${imageRoot}counter-scene.webp`,
    bundle: `${imageRoot}cash-bundle.webp`,
    stack: `${imageRoot}cash-stack.webp`,
    note: `${imageRoot}cash-note.webp`,
} as const

/** Most piles the counter shows; also the default. */
export const MAX_STACKS = 10

/** Splits the amount into the given number of piles, as evenly as possible. */
export function splitCash(
    amount: number,
    stackCount: number,
): number[] {
    if (!Number.isSafeInteger(amount) || amount <= 0) return []

    const count = Math.min(amount, stackCount)
    const base = Math.floor(amount / count)
    const remainder = amount % count

    return Array.from(
        { length: count },
        (_, index) => base + (index < remainder ? 1 : 0),
    )
}

export function cashPileGeometry(totalSlots: number) {
    const count = Math.max(1, totalSlots)
    const rise = Math.min(
        4.8,
        48 / Math.max(1, count - 1),
    )

    return {
        rise,
        height: 27.85 + (count - 1) * rise,
    }
}

export function trayPilePosition(
    slot: number,
    totalSlots: number,
) {
    const { rise } = cashPileGeometry(totalSlots)

    return {
        left: '16.425%',
        bottom: `${18 + slot * rise}%`,
        '--pile-order': slot + 1,
        zIndex: slot + 1,
    }
}