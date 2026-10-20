<script setup lang="ts">
import { useReviewStore } from '../stores/review.store'
import ReviewReceiptPaper from './ReviewReceiptPaper.vue'
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

defineProps<{
    pickedId: number | null
    draggingId: number | null
}>()

const emit = defineEmits<{
    pick: [event: PointerEvent, id: number]
    choose: [id: number]
}>()

const store = useReviewStore()

function clickReceipt(event: MouseEvent, id: number) {
    if (store.stage === 'select') {
        store.toggleReceipt(id)
        return
    }

    // Keyboard activation provides an alternative to dragging.
    if (event.detail === 0) emit('choose', id)
}
</script>

<template>
    <section class="review-receipt-tray" :aria-label="t('review.tray.label')">
        <div class="review-receipt-grid">
            <button
                v-for="receipt in store.visibleReceipts"
                :key="receipt.id"
                type="button"
                class="review-receipt"
                :class="{
                    'is-selected': store.stage === 'select'
                        ? store.selectedIds.includes(receipt.id)
                        : pickedId === receipt.id,
                    'is-dragging': draggingId === receipt.id,
                }"
                :aria-pressed="
                    store.stage === 'select'
                        ? store.selectedIds.includes(receipt.id)
                        : pickedId === receipt.id
                "
                :disabled="
                    (store.stage !== 'select' &&
                        store.stage !== 'prepare') ||
                    (store.stage === 'select' &&
                        store.isReceiptUnavailable(receipt.id))
                "
                :title="
                    store.stage === 'select' &&
                    store.receiptOvershoots(receipt)
                        ? t('review.tray.overshoot')
                        : undefined
                "
                @pointerdown="
                    store.stage === 'prepare' &&
                    emit('pick', $event, receipt.id)
                "
                @click="clickReceipt($event, receipt.id)"
            >
                <ReviewReceiptPaper :receipt="receipt" />

                <span
                    v-if="
                        store.stage === 'select' &&
                        store.selectedIds.includes(receipt.id)
                    "
                    class="review-receipt-mark"
                    aria-hidden="true"
                >
                    ✓
                </span>

                <span
                    v-if="
                        store.stage === 'prepare' &&
                        store.isReceiptAssigned(receipt.id)
                    "
                    class="review-receipt-assigned"
                >
                    {{ t('review.tray.attached') }}
                </span>
            </button>
        </div>

        <p
            v-if="!store.visibleReceipts.length"
            class="review-receipt-empty"
        >
            {{ t('review.tray.empty') }}
        </p>
    </section>

    <nav class="review-pagination" :aria-label="t('review.tray.pages')">
        <button
            type="button"
            :disabled="
                (store.stage !== 'select' &&
                    store.stage !== 'prepare') ||
                store.page === 0
            "
            :aria-label="t('review.tray.previousPage')"
            @click="store.changePage(-1)"
        >
            ‹
        </button>

        <span aria-live="polite">
            {{ store.page + 1 }} / {{ store.pageCount }}
        </span>

        <button
            type="button"
            :disabled="
                (store.stage !== 'select' &&
                    store.stage !== 'prepare') ||
                store.page >= store.pageCount - 1
            "
            :aria-label="t('review.tray.nextPage')"
            @click="store.changePage(1)"
        >
            ›
        </button>
    </nav>
</template>