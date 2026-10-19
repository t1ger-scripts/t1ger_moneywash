const imageRoot = `${import.meta.env.BASE_URL}images/`

export const raidImages = {
    scene: `${imageRoot}raid/raid-scene.webp`,
    bundle: `${imageRoot}cash-counter/cash-bundle.png`,
} as const

export function safePilePosition(index: number, total: number) {
    const columns = 3
    const rows = Math.ceil(total / columns)
    const rowSpacing = Math.min(
        8,
        30 / Math.max(1, rows - 1),
    )

    const rotations = [-5, 3, -2]

    return {
        left: `${25 + (index % columns) * 7.1}%`,
        top: `${18 + Math.floor(index / columns) * rowSpacing}%`,
        transform: `rotate(${rotations[index % columns]}deg)`,
        zIndex: index + 1,
    }
}