import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { useUiStore } from '@/shared/stores/ui.store'
import type { ReviewPayload } from '../review.types'

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

        if (folderFull.value) return
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
        formatMoney,
        formatDate,
        open,
        toggleReceipt,
        changePage,
        dismiss,
    }
})