<script setup lang="ts">
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'

defineProps<{
    overRowId: number | null
    pickedId: number | null
}>()

const emit = defineEmits<{
    place: [entryId: number]
}>()

const store = useReviewStore()
</script>

<template>
    <section class="review-worksheet" aria-label="Bookkeeping worksheet">
        <img
            class="review-worksheet-paper"
            :src="reviewImages.ledgerSheet"
            alt=""
            draggable="false"
        />

        <div class="review-worksheet-content">
            <header class="review-worksheet-header">
                <p>Delivery reconciliation</p>
                <h1>Prepare Books</h1>
                <p>{{ store.payload?.businessName }}</p>
            </header>

            <p class="review-worksheet-instructions">
                Attach each receipt to its row. Check units and total paid;
                edit only incorrect values.
            </p>

            <table class="review-worksheet-table">
                <thead>
                    <tr>
                        <th scope="col">Delivered</th>
                        <th scope="col">Units</th>
                        <th scope="col">Total paid</th>
                        <th scope="col">Receipt</th>
                    </tr>
                </thead>

                <tbody>
                    <tr
                        v-for="entry in store.visibleEntries"
                        :key="entry.id"
                        :data-review-row="entry.id"
                        :class="{ 'is-over': overRowId === entry.id }"
                    >
                        <td>
                            <span>{{ store.formatDate(entry.createdAt) }}</span>
                            <small>{{ store.formatTime(entry.createdAt) }}</small>
                        </td>

                        <td>
                            <input
                                v-model.number="entry.units"
                                type="number"
                                min="1"
                                step="1"
                                aria-label="Delivered units"
                            />
                        </td>

                        <td>
                            <span class="review-worksheet-money">
                                <span>{{ store.payload?.currency }}</span>

                                <input
                                    v-model.number="entry.totalAmount"
                                    type="number"
                                    min="0"
                                    step="1"
                                    aria-label="Total paid"
                                />
                            </span>
                        </td>

                        <td>
                            <div class="review-row-assignment">
                                <button
                                    type="button"
                                    class="review-row-drop"
                                    :disabled="pickedId === null"
                                    @click="emit('place', entry.id)"
                                >
                                    {{
                                        entry.matchedReceiptId === null
                                            ? 'Attach receipt'
                                            : `#${entry.matchedReceiptId}`
                                    }}
                                </button>

                                <button
                                    v-if="entry.matchedReceiptId !== null"
                                    type="button"
                                    class="review-row-remove"
                                    aria-label="Remove attached receipt"
                                    @click="store.unassignReceipt(entry.id)"
                                >
                                    ×
                                </button>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>

            <footer class="review-worksheet-footer">
                <span aria-live="polite">
                    {{ store.assignedCount }} / {{ store.entries.length }}
                    receipts attached
                </span>

                <nav aria-label="Worksheet pages">
                    <button
                        type="button"
                        :disabled="store.sheetPage === 0"
                        aria-label="Previous worksheet page"
                        @click="store.changeSheetPage(-1)"
                    >
                        ‹
                    </button>

                    <span>
                        {{ store.sheetPage + 1 }} / {{ store.sheetPageCount }}
                    </span>

                    <button
                        type="button"
                        :disabled="
                            store.sheetPage >= store.sheetPageCount - 1
                        "
                        aria-label="Next worksheet page"
                        @click="store.changeSheetPage(1)"
                    >
                        ›
                    </button>
                </nav>
            </footer>
        </div>
    </section>
</template>