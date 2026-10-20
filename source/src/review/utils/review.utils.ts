const imageRoot = `${import.meta.env.BASE_URL}images/review/`

export const reviewImages = {
    scene: `${imageRoot}review-scene.png`,
    receipt: `${imageRoot}receipt.png`,
    ledgerSheet: `${imageRoot}ledger-sheet.png`,
    worksheet: `${imageRoot}worksheet-sheet.png`,
    folderOpen: `${imageRoot}folder-open.png`,
    folderClosed: `${imageRoot}folder-closed.png`,
    stamp: `${imageRoot}stamp.png`,
} as const

export function formatReviewDateInput(timestamp: number): string {
    return new Date(timestamp * 1000).toISOString().slice(0, 10)
}