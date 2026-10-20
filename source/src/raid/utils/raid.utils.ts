const imageRoot = `${import.meta.env.BASE_URL}images/`

export const raidImages = {
    scene: `${imageRoot}raid/raid-scene.webp`,
    bundle: `${imageRoot}cash-counter/cash-bundle.png`,
} as const

export function createSafePileLayout(
    total: number,
    unavailableIds: number[],
) {
    const columns = Math.min(2, total)
    const unavailable = new Set(unavailableIds)
    const columnHeights = [0, 0]

    const layout = []

    for (let id = 0; id < total; id++) {
        if (unavailable.has(id)) continue

        const column = id % columns
        const layer = columnHeights[column]++

        const columnOffset =
            column - (columns - 1) / 2

        const rotation = column === 0 ? -1 : 0.8

        layout.push({
            id,
            style: {
                left: `${36.5 + columnOffset * 10.6}%`,
                bottom: `${44.8 + layer * 1.1}%`,
                transform:
                    `translateX(-50%) rotate(${rotation}deg)`,
                zIndex: layer + 1,
                '--cash-brightness': '0.95',
            },
        })
    }

    return layout
}

export function splitRaidCash(
    amount: number,
    stackCount: number,
): number[] {
    if (!Number.isSafeInteger(amount) || amount <= 0) return []

    const configured = Number.isFinite(stackCount)
        ? Math.floor(stackCount)
        : 10

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

export function isRaidBagDropPoint(
    event: PointerEvent,
    target: Element,
): boolean {
    const shape = target.querySelector<SVGPathElement>(
        '[data-raid-drop-shape]',
    )

    const matrix = shape?.getScreenCTM()

    if (!shape || !matrix) return false

    const point = new DOMPoint(
        event.clientX,
        event.clientY,
    ).matrixTransform(matrix.inverse())

    return shape.isPointInFill(point)
}