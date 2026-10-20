<script setup lang="ts">
import type { ReviewReceipt } from '../review.types'
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'
import ReviewAmount from './ReviewAmount.vue'

defineProps<{
    receipt: ReviewReceipt
}>()

const store = useReviewStore()
</script>

<template>
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
            <span>{{ store.formatDate(receipt.createdAt) }}</span>
            <span>{{ store.formatTime(receipt.createdAt) }}</span>
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
</template>