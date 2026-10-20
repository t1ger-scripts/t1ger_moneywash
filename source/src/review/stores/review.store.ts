import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { useUiStore } from '@/shared/stores/ui.store'
import type { ReviewPayload, ReviewReceipt } from '../review.types'

const PAGE_SIZE = 6

export const useReviewStore = defineStore('review', () => {
    const ui = useUiStore()

    const payload = ref<ReviewPayload | null>(null)
    const page = ref(0)
    const selectedIds = ref<number[]>([])

    const receipts = computed(() => payload.value?.receipts ?? [])

    const maxReceipts = computed(() =>
        Math.max(1, Math.floor(payload.value?.maxReceipts ?? 12)),
    )

    const pageCount = computed(() =>
        Math.max(1, Math.ceil(receipts.value.length / PAGE_SIZE)),
    )

    const visibleReceipts = computed(() => {
        const start = page.value * PAGE_SIZE

        return receipts.value.slice(start, start + PAGE_SIZE)
    })

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

        ui.open('review')
    }

    function toggleReceipt(id: number) {
        const index = selectedIds.value.indexOf(id)

        if (index !== -1) {
            selectedIds.value.splice(index, 1)
            return
        }

        if (isReceiptUnavailable(id)) return
        if (!receipts.value.some((receipt) => receipt.id === id)) return

        selectedIds.value.push(id)
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