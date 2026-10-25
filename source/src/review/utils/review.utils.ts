const imageRoot = `${import.meta.env.BASE_URL}images/review/`

export const reviewImages = {
    scene: `${imageRoot}review-scene.webp`,
    receipt: `${imageRoot}receipt.webp`,
    ledgerSheet: `${imageRoot}ledger-sheet.webp`,
    worksheet: `${imageRoot}worksheet-sheet.webp`,
    folderOpen: `${imageRoot}folder-open.webp`,
    folderClosed: `${imageRoot}folder-closed.webp`,
    stamp: `${imageRoot}stamp.webp`,
} as const