<script setup lang="ts">
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'
import ReviewAmount from './ReviewAmount.vue'

const store = useReviewStore()
</script>

<template>
    <section class="review-receipt-tray" aria-label="Available receipts">
        <div class="review-receipt-grid">
            <button
                v-for="receipt in store.visibleReceipts"
                :key="receipt.id"
                type="button"
                class="review-receipt"
                :class="{
                    'is-selected': store.selectedIds.includes(receipt.id),
                }"
                :aria-pressed="store.selectedIds.includes(receipt.id)"
                :disabled="
                    store.folderFull &&
                    !store.selectedIds.includes(receipt.id)
                "
                @click="store.toggleReceipt(receipt.id)"
            >
                <img
                    :src="reviewImages.receipt"
                    alt=""
                    draggable="false"
                />

                <span class="review-receipt-content">
                    <span class="review-receipt-heading">
                        Receipt #{{ receipt.id }}
                    </span>

                    <span class="review-receipt-delivery">
                        <span>
                            {{ store.formatDate(receipt.createdAt) }}
                        </span>

                        <span>
                            {{ store.formatTime(receipt.createdAt) }}
                        </span>
                    </span>

                    <span class="review-receipt-line">
                        <span>Units</span>
                        <strong>{{ receipt.units }}</strong>
                    </span>

                    <span class="review-receipt-total">
                        <span>Total paid</span>

                        <ReviewAmount
                            :value="store.formatMoney(receipt.totalAmount)"
                        />
                    </span>
                </span>

                <span
                    v-if="store.selectedIds.includes(receipt.id)"
                    class="review-receipt-mark"
                    aria-hidden="true"
                >
                    ✓
                </span>
            </button>
        </div>

        <p
            v-if="!store.visibleReceipts.length"
            class="review-receipt-empty"
        >
            No stock-delivery receipts available.
        </p>
    </section>

    <nav class="review-pagination" aria-label="Receipt pages">
        <button
            type="button"
            :disabled="store.page === 0"
            aria-label="Previous receipt page"
            @click="store.changePage(-1)"
        >
            ‹
        </button>

        <span aria-live="polite">
            {{ store.page + 1 }} / {{ store.pageCount }}
        </span>

        <button
            type="button"
            :disabled="store.page >= store.pageCount - 1"
            aria-label="Next receipt page"
            @click="store.changePage(1)"
        >
            ›
        </button>
    </nav>
</template>