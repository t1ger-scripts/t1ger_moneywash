<script setup lang="ts">
import type { ReviewReceipt } from '../review.types'
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'
import ReviewAmount from './ReviewAmount.vue'
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

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
            {{ t('review.receipt.heading', { id: receipt.id }) }}
        </span>

        <span class="review-receipt-delivery">
            {{ store.formatDate(receipt.createdAt) }}
        </span>

        <span class="review-receipt-line">
            <span>{{ t('review.receipt.units') }}</span>
            <strong>{{ receipt.units }}</strong>
        </span>

        <span class="review-receipt-total">
            <span>{{ t('review.receipt.totalPaid') }}</span>

            <ReviewAmount
                :value="store.formatMoney(receipt.totalAmount)"
            />
        </span>
    </span>
</template>