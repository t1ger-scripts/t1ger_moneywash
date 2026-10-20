<script setup lang="ts">
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'

const store = useReviewStore()
</script>

<template>
    <section
        class="review-summary review-worksheet"
        aria-label="Bookkeeping worksheet"
    >
        <img
            class="review-summary-paper"
            :src="reviewImages.ledgerSheet"
            alt=""
            draggable="false"
        />

        <div class="review-summary-content">
            <p class="review-summary-eyebrow">Delivery reconciliation</p>

            <h1>Prepare Books</h1>

            <p class="review-summary-business">
                {{ store.payload?.businessName }}
            </p>

            <template v-if="store.activeEntry">
                <nav
                    class="review-entry-navigation"
                    aria-label="Worksheet entries"
                >
                    <button
                        type="button"
                        :disabled="store.activeEntryIndex === 0"
                        aria-label="Previous entry"
                        @click="store.changeEntry(-1)"
                    >
                        ‹
                    </button>

                    <span aria-live="polite">
                        Entry {{ store.activeEntryIndex + 1 }}
                        / {{ store.entries.length }}
                    </span>

                    <button
                        type="button"
                        :disabled="
                            store.activeEntryIndex >= store.entries.length - 1
                        "
                        aria-label="Next entry"
                        @click="store.changeEntry(1)"
                    >
                        ›
                    </button>
                </nav>

                <dl class="review-summary-totals">
                    <div>
                        <dt>Delivered</dt>
                        <dd>
                            {{ store.formatDate(store.activeEntry.createdAt) }}
                        </dd>
                    </div>

                    <div>
                        <dt>Time</dt>
                        <dd>
                            {{ store.formatTime(store.activeEntry.createdAt) }}
                        </dd>
                    </div>

                    <div>
                        <dt>Units</dt>
                        <dd>{{ store.activeEntry.units }}</dd>
                    </div>

                    <div>
                        <dt>Total paid</dt>
                        <dd>
                            {{
                                store.formatMoney(
                                    store.activeEntry.totalAmount,
                                )
                            }}
                        </dd>
                    </div>
                </dl>

                <p class="review-entry-match" aria-live="polite">
                    {{
                        store.activeEntry.matchedReceiptId === null
                            ? 'Click the matching receipt in the tray.'
                            : `Assigned: Receipt #${store.activeEntry.matchedReceiptId}`
                    }}
                </p>

                <p class="review-entry-progress">
                    {{ store.matchedCount }}
                    / {{ store.entries.length }} entries matched
                </p>
            </template>

            <button
                type="button"
                class="review-paper-button review-back-button"
                @click="store.backToSelection"
            >
                Back to receipts
            </button>
        </div>
    </section>
</template>