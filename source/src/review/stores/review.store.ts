import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { useUiStore } from '@/shared/stores/ui.store'
import type { ReviewPayload, ReviewReceipt, ReviewEntry } from '../review.types'

const PAGE_SIZE = 6

export const useReviewStore = defineStore('review', () => {
    const ui = useUiStore()

    const payload = ref<ReviewPayload | null>(null)
    const page = ref(0)
    const selectedIds = ref<number[]>([])

    const stage = ref<'select' | 'prepare'>('select')
    const entries = ref<ReviewEntry[]>([])
    const activeEntryIndex = ref(0)

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

    const activeEntry = computed(() =>
        entries.value[activeEntryIndex.value] ?? null,
    )

    const matchedCount = computed(() =>
        entries.value.filter(
            (entry) => entry.matchedReceiptId !== null,
        ).length,
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
        if (selectedIds.value.length === 0) {
            return 'Select receipts from the tray to prepare your books.'
        }

        if (!meetsMinimum.value) {
            const minimum = payload.value?.settings.minReduction ?? 0

            return `Select more receipts to reach at least ${
                formatReduction(minimum)
            } points of potential reduction.`
        }

        if (capReached.value) {
            return uncappedReduction.value > reductionCap.value
                ? 'Reduction cap reached. Excess receipt value will be used without increasing the reduction.'
                : 'Reduction cap reached. Your selection is ready.'
        }

        if (folderFull.value) {
            return 'Folder full. Your selection is ready.'
        }

        return 'Selection ready. Add more receipts for a greater potential reduction.'
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

    const timeFormatter = computed(() =>
        new Intl.DateTimeFormat(payload.value?.locale ?? 'en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: false,
            timeZone: 'UTC',
        }),
    )

    

    function formatMoney(amount: number): string {
        return `${payload.value?.currency ?? '$'}${moneyFormatter.value.format(amount)}`
    }

    function formatDate(timestamp: number): string {
        return dateFormatter.value.format(new Date(timestamp * 1000))
    }

    function formatTime(timestamp: number): string {
        return timeFormatter.value.format(new Date(timestamp * 1000))
    }

    function open(data: ReviewPayload) {
        payload.value = data
        page.value = 0
        selectedIds.value = []
        stage.value = 'select'
        entries.value = []
        activeEntryIndex.value = 0

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

    function prepareBooks() {
        if (stage.value !== 'select' || !meetsMinimum.value) return

        // Dev worksheet. Later, the server will supply these entries.
        const worksheet: ReviewEntry[] = selectedReceipts.value.map(
            (receipt) => ({
                id: receipt.id,
                units: receipt.units,
                totalAmount: receipt.totalAmount,
                createdAt: receipt.createdAt,
                matchedReceiptId: null,
            }),
        )

        // Shuffle without changing the receipt order in the tray.
        for (let index = worksheet.length - 1; index > 0; index--) {
            const target = Math.floor(Math.random() * (index + 1))

            const entry = worksheet[index]!
            worksheet[index] = worksheet[target]!
            worksheet[target] = entry
        }

        entries.value = worksheet
        activeEntryIndex.value = 0
        page.value = 0
        stage.value = 'prepare'
    }

    function matchReceipt(id: number) {
        if (stage.value !== 'prepare' || !activeEntry.value) return
        if (!selectedIds.value.includes(id)) return

        activeEntry.value.matchedReceiptId = id
    }

    function changeEntry(direction: -1 | 1) {
        activeEntryIndex.value = Math.max(
            0,
            Math.min(
                entries.value.length - 1,
                activeEntryIndex.value + direction,
            ),
        )
    }

    function backToSelection() {
        stage.value = 'select'
        entries.value = []
        activeEntryIndex.value = 0
        page.value = 0
    }

    function changePage(direction: -1 | 1) {
        page.value = Math.max(
            0,
            Math.min(pageCount.value - 1, page.value + direction),
        )
    }

    function dismiss() {
        ui.close('review')

        payload.value = null
        page.value = 0
        selectedIds.value = []
        stage.value = 'select'
        entries.value = []
        activeEntryIndex.value = 0
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
        activeEntryIndex,
        activeEntry,
        matchedCount,
        prepareBooks,
        matchReceipt,
        changeEntry,
        backToSelection,
        formatReduction,
        isReceiptUnavailable,
        receiptOvershoots,
        formatMoney,
        formatDate,
        formatTime,
        open,
        toggleReceipt,
        changePage,
        dismiss,
    }
})