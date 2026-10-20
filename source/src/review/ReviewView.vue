<script setup lang="ts">
import ReviewReceiptTray from './components/ReviewReceiptTray.vue'
import { useReviewStore } from './stores/review.store'
import { reviewImages } from './utils/review.utils'
import './styles/review.scss'

const store = useReviewStore()
</script>

<template>
    <div class="review-overlay">
        <section
            class="review-scene"
            role="dialog"
            aria-modal="true"
            aria-label="Review business books"
            tabindex="-1"
        >
            <img
                class="review-scene-image"
                :src="reviewImages.scene"
                alt=""
                draggable="false"
            />

            <ReviewReceiptTray />

            <section
                class="review-summary"
                aria-label="Selected receipt summary"
            >
                <img
                    class="review-summary-paper"
                    :src="reviewImages.ledgerSheet"
                    alt=""
                    draggable="false"
                />

                <div class="review-summary-content">
                    <p class="review-summary-eyebrow">Accountant review</p>

                    <h1>Review Books</h1>

                    <p class="review-summary-business">
                        {{ store.payload?.businessName }}
                    </p>

                    <dl class="review-summary-totals">
                        <div>
                            <dt>Receipts selected</dt>
                            <dd>{{ store.selectedIds.length }}</dd>
                        </div>

                        <div>
                            <dt>Delivered units</dt>
                            <dd>{{ store.selectedUnits }}</dd>
                        </div>

                        <div>
                            <dt>Purchase value</dt>
                            <dd>
                                {{ store.formatMoney(store.selectedAmount) }}
                            </dd>
                        </div>
                    </dl>

                    <p class="review-summary-hint" aria-live="polite">
                        {{
                            store.folderFull
                                ? 'Folder full. Deselect a receipt to make room.'
                                : 'Select receipts from the tray to prepare your books.'
                        }}
                    </p>
                </div>
            </section>
        </section>
    </div>
</template>