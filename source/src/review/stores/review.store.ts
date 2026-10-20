import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { useUiStore } from '@/shared/stores/ui.store'
import { i18n, installLocaleMessages } from '@/integrations/i18n'
import { NUI_CALLBACKS, postNui } from '@/integrations/nui'
import type {
    ReviewPayload,
    ReviewReceipt,
    ReviewEntry,
    ReviewStage,
    ReviewResult,
    ReviewPrepareResponse,
    ReviewStampResponse,
} from '../review.types'

const PAGE_SIZE = 6
const SHEET_PAGE_SIZE = 8

export const useReviewStore = defineStore('review', () => {
    const ui = useUiStore()

    const payload = ref<ReviewPayload | null>(null)
    const page = ref(0)
    const selectedIds = ref<number[]>([])

    const stage = ref<ReviewStage>('select')
    const result = ref<ReviewResult | null>(null)

    const submitting = ref(false)
    const errorMessage = ref('')

    let finishTimer: ReturnType<typeof setTimeout> | undefined

    // Bumped on every open/dismiss so late server replies are ignored.
    let generation = 0

    const entries = ref<ReviewEntry[]>([])
    const sheetPage = ref(0)

    const receipts = computed(() => payload.value?.receipts ?? [])

    const maxReceipts = computed(() =>
        Math.max(1, Math.floor(payload.value?.maxReceipts ?? 12)),
    )

    const trayReceipts = computed(() => {
        if (stage.value === 'select') return receipts.value

        const ids = new Set(selectedIds.value)

        return receipts.value.filter((receipt) => ids.has(receipt.id))
    })

    const pageCount = computed(() =>
        Math.max(1, Math.ceil(trayReceipts.value.length / PAGE_SIZE)),
    )

    const visibleReceipts = computed(() => {
        const start = page.value * PAGE_SIZE

        return trayReceipts.value.slice(start, start + PAGE_SIZE)
    })

    const sheetPageCount = computed(() =>
        Math.max(
            1,
            Math.ceil(entries.value.length / SHEET_PAGE_SIZE),
        ),
    )

    const visibleEntries = computed(() => {
        const start = sheetPage.value * SHEET_PAGE_SIZE

        return entries.value.slice(start, start + SHEET_PAGE_SIZE)
    })

    const assignedCount = computed(() =>
        entries.value.filter(
            (entry) => entry.matchedReceiptId !== null,
        ).length,
    )

    const canStamp = computed(() =>
        stage.value === 'prepare' &&
        !submitting.value &&
        entries.value.length > 0 &&
        assignedCount.value === entries.value.length,
    )

    const selectedReceipts = computed(() => {
        const ids = new Set(selectedIds.value)

        return receipts.value.filter((receipt) => ids.has(receipt.id))
    })

    const selectedUnits = computed(() =>
        selectedReceipts.value.reduce(
            (total, receipt) => total + receipt.units,
            0,
        ),
    )

    const selectedAmount = computed(() =>
        selectedReceipts.value.reduce(
            (total, receipt) => total + receipt.totalAmount,
            0,
        ),
    )

    const folderFull = computed(() =>
        selectedIds.value.length >= maxReceipts.value,
    )

    const reductionPerUnit = computed(() => {
        const data = payload.value

        if (
            !data ||
            data.expectedRevenue <= 0 ||
            data.launderDollarsPerUnit <= 0 ||
            data.settings.cyclesForMax <= 0 ||
            data.settings.maxReduction <= 0
        ) return 0

        const unitsPerCycle =
            data.expectedRevenue / data.launderDollarsPerUnit

        return data.settings.maxReduction /
            data.settings.cyclesForMax /
            unitsPerCycle
    })

    const reductionCap = computed(() =>
        Math.max(
            0,
            Math.min(
                payload.value?.settings.maxReduction ?? 0,
                payload.value?.suspicion ?? 0,
            ),
        ),
    )

    const uncappedReduction = computed(() =>
        selectedUnits.value * reductionPerUnit.value,
    )

    const baseReduction = computed(() =>
        Math.min(uncappedReduction.value, reductionCap.value),
    )

    const capReached = computed(() =>
        reductionCap.value > 0 &&
        uncappedReduction.value >= reductionCap.value,
    )

    const fee = computed(() => {
        const data = payload.value

        if (!data) return 0

        return Math.round(
            data.expectedRevenue * data.settings.feePercent / 100,
        )
    })

    const expectedSuspicion = computed(() =>
        Math.max(
            0,
            (payload.value?.suspicion ?? 0) - baseReduction.value,
        ),
    )

    const meetsMinimum = computed(() =>
        selectedIds.value.length > 0 &&
        baseReduction.value > 0 &&
        baseReduction.value >=
        (payload.value?.settings.minReduction ?? 0),
    )

    const selectionHint = computed(() => {
        const t = i18n.global.t

        if (selectedIds.value.length === 0) {
            return t('review.hint.empty')
        }

        if (!meetsMinimum.value) {
            return t('review.hint.minimum', {
                minimum: formatReduction(
                    payload.value?.settings.minReduction ?? 0,
                ),
            })
        }

        if (capReached.value) {
            return uncappedReduction.value > reductionCap.value
                ? t('review.hint.capExcess')
                : t('review.hint.capReady')
        }

        if (folderFull.value) return t('review.hint.folderFull')

        return t('review.hint.ready')
    })

    function formatReduction(value: number): string {
        return value.toLocaleString(
            payload.value?.locale ?? 'en-US',
            { maximumFractionDigits: 1 },
        )
    }

    function isReceiptUnavailable(id: number): boolean {
        if (selectedIds.value.includes(id)) return false

        return folderFull.value ||
            capReached.value ||
            reductionCap.value === 0
    }

    function receiptOvershoots(receipt: ReviewReceipt): boolean {
        if (selectedIds.value.includes(receipt.id)) return false
        if (isReceiptUnavailable(receipt.id)) return false

        return uncappedReduction.value +
            receipt.units * reductionPerUnit.value >
            reductionCap.value
    }

    const moneyFormatter = computed(() =>
        new Intl.NumberFormat(payload.value?.locale ?? 'en-US', {
            maximumFractionDigits: 0,
        }),
    )

    const dateFormatter = computed(() =>
        new Intl.DateTimeFormat(payload.value?.locale ?? 'en-US', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            timeZone: 'UTC',
        }),
    )

    function formatMoney(amount: number): string {
        return `${payload.value?.currency ?? '$'}${moneyFormatter.value.format(amount)}`
    }

    function formatDate(timestamp: number): string {
        return dateFormatter.value.format(new Date(timestamp * 1000))
    }

    function open(data: ReviewPayload) {
        generation++
        clearTimeout(finishTimer)

        installLocaleMessages(data.locale, data.messages)

        payload.value = data
        result.value = null
        submitting.value = false
        errorMessage.value = ''
        page.value = 0
        selectedIds.value = []
        stage.value = 'select'
        entries.value = []
        sheetPage.value = 0

        ui.open('review')
    }

    function toggleReceipt(id: number) {
        if (stage.value !== 'select') return

        const index = selectedIds.value.indexOf(id)

        if (index !== -1) {
            selectedIds.value.splice(index, 1)
            return
        }

        if (isReceiptUnavailable(id)) return
        if (!receipts.value.some((receipt) => receipt.id === id)) return

        selectedIds.value.push(id)
    }

    function failureMessage(
        response: { reason?: string; message?: string } | null,
    ): string {
        const key = `review.errors.${response?.reason ?? ''}`

        if (i18n.global.te(key)) return i18n.global.t(key)

        return response?.message ||
            i18n.global.t('review.errors.request_failed')
    }

    async function prepareBooks() {
        if (
            stage.value !== 'select' ||
            !meetsMinimum.value ||
            !payload.value ||
            submitting.value
        ) return

        const current = generation

        submitting.value = true
        errorMessage.value = ''

        let response: ReviewPrepareResponse | null = null

        try {
            response = await postNui<
                ReviewPrepareResponse,
                { ids: number[] }
            >(NUI_CALLBACKS.reviewPrepare, {
                ids: [...selectedIds.value],
            })
        } catch {
            response = null
        }

        if (current !== generation) return

        submitting.value = false

        if (!response?.success || !response.rows) {
            errorMessage.value = failureMessage(response)
            return
        }

        entries.value = response.rows.map((row) => ({
            id: row.id,
            createdAt: row.createdAt,
            units: row.units,
            totalAmount: row.totalAmount,
            matchedReceiptId: null,
        }))

        sheetPage.value = 0
        page.value = 0
        stage.value = 'prepare'
    }

    function assignReceipt(entryId: number, receiptId: number) {
        if (stage.value !== 'prepare') return
        if (!selectedIds.value.includes(receiptId)) return

        const target = entries.value.find(
            (entry) => entry.id === entryId,
        )

        if (!target) return

        // One receipt can only be attached to one row.
        for (const entry of entries.value) {
            if (entry.matchedReceiptId === receiptId) {
                entry.matchedReceiptId = null
            }
        }

        // Replacing an assignment releases the previous receipt.
        target.matchedReceiptId = receiptId
    }

    function unassignReceipt(entryId: number) {
        if (stage.value !== 'prepare') return

        const entry = entries.value.find(
            (item) => item.id === entryId,
        )

        if (entry) entry.matchedReceiptId = null
    }

    function isReceiptAssigned(receiptId: number): boolean {
        return entries.value.some(
            (entry) => entry.matchedReceiptId === receiptId,
        )
    }

    function changeSheetPage(direction: -1 | 1) {
        if (stage.value !== 'prepare') return

        sheetPage.value = Math.max(
            0,
            Math.min(
                sheetPageCount.value - 1,
                sheetPage.value + direction,
            ),
        )
    }

    // The stamp drop needs an immediate yes/no; the server answer follows.
    function stampBooks(): boolean {
        if (!canStamp.value || !payload.value) return false

        void commitStamp()

        return true
    }

    async function commitStamp() {
        const current = generation

        submitting.value = true
        errorMessage.value = ''

        let response: ReviewStampResponse | null = null

        try {
            response = await postNui<
                ReviewStampResponse,
                {
                    rows: Array<{
                        id: number
                        matchedReceiptId: number | null
                        units: number | string
                        totalAmount: number | string
                    }>
                }
            >(NUI_CALLBACKS.reviewStamp, {
                rows: entries.value.map((entry) => ({
                    id: entry.id,
                    matchedReceiptId: entry.matchedReceiptId,
                    units: entry.units,
                    totalAmount: entry.totalAmount,
                })),
            })
        } catch {
            response = null
        }

        if (current !== generation) return

        submitting.value = false

        if (!response?.success || !response.result) {
            errorMessage.value = failureMessage(response)

            // The server dropped the sheet: start over from the receipts.
            if (
                response?.reason === 'not_prepared' ||
                response?.reason === 'no_review'
            ) {
                entries.value = []
                stage.value = 'select'
            }

            return
        }

        result.value = response.result
        stage.value = 'stamped'

        const reducedMotion = window.matchMedia(
            '(prefers-reduced-motion: reduce)',
        ).matches

        clearTimeout(finishTimer)

        finishTimer = setTimeout(() => {
            if (stage.value !== 'stamped') return

            stage.value = 'filing'

            finishTimer = setTimeout(() => {
                finishTimer = undefined

                if (stage.value !== 'filing') return

                stage.value = 'complete'
                void finishReview()
            }, reducedMotion ? 100 : 1900)
        }, reducedMotion ? 100 : 650)
    }

    // Tells the client the paperwork is filed: it closes the UI and
    // starts the delivery mission.
    async function finishReview() {
        try {
            await postNui(NUI_CALLBACKS.reviewClose)
        } catch {
            // Resource shutdown also performs cleanup.
        }

        ui.close('review')
    }

    function changePage(direction: -1 | 1) {
        if (stage.value !== 'select' && stage.value !== 'prepare') return
        page.value = Math.max(
            0,
            Math.min(pageCount.value - 1, page.value + direction),
        )
    }

    // Back button: discard the worksheet. The server replaces the old
    // sheet the next time books are prepared.
    function back() {
        if (stage.value !== 'prepare' || submitting.value) return

        entries.value = []
        sheetPage.value = 0
        page.value = 0
        errorMessage.value = ''
        stage.value = 'select'
    }

    // ESC before the stamp: tell the client to discard and close.
    async function cancel() {
        if (submitting.value) return
        if (stage.value !== 'select' && stage.value !== 'prepare') return

        submitting.value = true

        try {
            await postNui(NUI_CALLBACKS.reviewCancel)
        } catch {
            // Resource shutdown also performs cleanup.
        }

        dismiss()
    }

    // The client closed the UI (cancelled, timed out, died).
    function dismiss() {
        generation++
        clearTimeout(finishTimer)

        ui.close('review')

        payload.value = null
        result.value = null
        page.value = 0
        selectedIds.value = []
        stage.value = 'select'
        entries.value = []
        sheetPage.value = 0
        submitting.value = false
        errorMessage.value = ''
    }

    return {
        payload,
        page,
        pageCount,
        visibleReceipts,
        selectedIds,
        selectedReceipts,
        selectedUnits,
        selectedAmount,
        maxReceipts,
        folderFull,
        baseReduction,
        capReached,
        fee,
        expectedSuspicion,
        meetsMinimum,
        selectionHint,
        stage,
        entries,
        sheetPage,
        sheetPageSize: SHEET_PAGE_SIZE,
        sheetPageCount,
        visibleEntries,
        assignedCount,
        result,
        canStamp,
        submitting,
        errorMessage,
        back,
        cancel,
        stampBooks,
        assignReceipt,
        unassignReceipt,
        isReceiptAssigned,
        changeSheetPage,
        prepareBooks,
        formatReduction,
        isReceiptUnavailable,
        receiptOvershoots,
        formatMoney,
        formatDate,
        open,
        toggleReceipt,
        changePage,
        dismiss,
    }
})