<script setup lang="ts">
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

defineProps<{
    overRowId: number | null
    pickedId: number | null
    stampOver: boolean
}>()

const emit = defineEmits<{
    place: [entryId: number]
}>()

const store = useReviewStore()
</script>

<template>
    <section class="review-worksheet" :aria-label="t('review.worksheet.label')">
        <img
            class="review-worksheet-paper"
            :src="reviewImages.worksheet"
            alt=""
            draggable="false"
        />

        <div class="review-worksheet-content">
            <header class="review-worksheet-header">
                <button
                    type="button"
                    class="review-worksheet-back"
                    :disabled="store.stage !== 'prepare' || store.submitting"
                    @click="store.back"
                >
                    {{ t('review.back') }}
                </button>

                <h1>{{ t('review.worksheet.title') }}</h1>

                <p class="review-worksheet-instructions">
                    {{ t('review.worksheet.instructions') }}
                </p>
            </header>

            <table
                class="review-worksheet-table"
                :style="{ '--review-sheet-rows': store.sheetPageSize }"
            >
                <thead>
                    <tr>
                        <th scope="col">{{ t('review.worksheet.receiptNumber') }}</th>
                        <th scope="col">{{ t('review.worksheet.date') }}</th>
                        <th scope="col">{{ t('review.worksheet.units') }}</th>
                        <th scope="col">{{ t('review.worksheet.totalPaid') }}</th>
                        <th scope="col">{{ t('review.worksheet.attached') }}</th>
                    </tr>
                </thead>

                <tbody>
                    <tr
                        v-for="entry in store.visibleEntries"
                        :key="entry.id"
                        :data-review-row="entry.id"
                        :class="{ 'is-over': overRowId === entry.id }"
                    >
                        <td class="review-receipt-reference">
                            #{{ entry.id }}
                        </td>

                        <td>
                            {{ store.formatDate(entry.createdAt) }}
                        </td>

                        <td>
                            <input
                                v-model.number="entry.units"
                                type="number"
                                :disabled="store.stage !== 'prepare'"
                                min="1"
                                step="1"
                                :aria-label="
                                    t('review.worksheet.unitsFor', { id: entry.id })
                                "
                            />
                        </td>

                        <td>
                            <span class="review-worksheet-money">
                                <span>{{ store.payload?.currency }}</span>

                                <input
                                    v-model.number="entry.totalAmount"
                                    type="number"
                                    :disabled="store.stage !== 'prepare'"
                                    min="0"
                                    step="1"
                                    :aria-label="
                                        t('review.worksheet.totalFor', { id: entry.id })
                                    "
                                />
                            </span>
                        </td>

                        <td>
                            <div class="review-row-assignment">
                                <button
                                    type="button"
                                    class="review-row-attachment"
                                    :disabled="
                                        pickedId === null ||
                                        store.stage !== 'prepare'
                                    "
                                    :aria-label="
                                        t('review.worksheet.attach', { id: entry.id })
                                    "
                                    :title="
                                        entry.matchedReceiptId === null
                                            ? t('review.worksheet.noReceipt')
                                            : t('review.worksheet.attachedReceipt', { id: entry.matchedReceiptId })
                                    "
                                    @click="emit('place', entry.id)"
                                >
                                    <svg
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        stroke-width="1.5"
                                        stroke-linecap="round"
                                        stroke-linejoin="round"
                                        aria-hidden="true"
                                    >
                                        <path
                                            d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"
                                        />
                                        <path d="M14 2v6h6M8 13h8M8 17h6" />
                                    </svg>

                                    <span
                                        v-if="entry.matchedReceiptId !== null"
                                    >
                                        #{{ entry.matchedReceiptId }}
                                    </span>
                                </button>

                                <button
                                    v-if="entry.matchedReceiptId !== null"
                                    type="button"
                                    class="review-row-remove"
                                    :disabled="store.stage !== 'prepare'"
                                    :aria-label="
                                        t('review.worksheet.remove', { id: entry.id })
                                    "
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
                <div
                    v-if="store.canStamp || store.stage === 'stamped'"
                    class="review-stamp-target"
                    :class="{
                        'is-over': stampOver,
                        'is-stamped': store.stage === 'stamped',
                    }"
                    data-review-stamp-target
                    aria-live="polite"
                >
                    {{
                        store.stage === 'stamped'
                            ? t('review.prepared')
                            : t('review.stampToCommit')
                    }}
                </div>

                <span
                    v-else
                    class="review-worksheet-status"
                    aria-live="polite"
                >
                    {{
                        t('review.worksheet.progress', {
                            assigned: store.assignedCount,
                            total: store.entries.length,
                        })
                    }}
                </span>

                <nav :aria-label="t('review.worksheet.pages')">
                    <button
                        type="button"
                        :disabled="
                            store.stage !== 'prepare' ||
                            store.sheetPage === 0
                        "
                        :aria-label="t('review.worksheet.previousPage')"
                        @click="store.changeSheetPage(-1)"
                    >
                        ‹ {{ t('review.previous') }}
                    </button>

                    <span
                        class="review-worksheet-page"
                        aria-live="polite"
                    >
                        {{
                            t('review.worksheet.page', {
                                page: store.sheetPage + 1,
                                pages: store.sheetPageCount,
                            })
                        }}
                    </span>

                    <button
                        type="button"
                        :disabled="
                            store.stage !== 'prepare' ||
                            store.sheetPage >= store.sheetPageCount - 1
                        "
                        :aria-label="t('review.worksheet.nextPage')"
                        @click="store.changeSheetPage(1)"
                    >
                        {{ t('review.next') }} ›
                    </button>
                </nav>
            </footer>
        </div>
    </section>
</template>