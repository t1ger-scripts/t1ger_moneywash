<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import ReviewReceiptTray from './components/ReviewReceiptTray.vue'
import ReviewWorksheet from './components/ReviewWorksheet.vue'
import ReviewReceiptPaper from './components/ReviewReceiptPaper.vue'
import ReviewStamp from './components/ReviewStamp.vue'
import ReviewFolder from './components/ReviewFolder.vue'
import { useReviewStamp } from './composables/useReviewStamp'
import { useReviewDrag } from './composables/useReviewDrag'
import { useReviewStore } from './stores/review.store'
import { reviewImages } from './utils/review.utils'
import './styles/review.scss'

const store = useReviewStore()

const root = ref<HTMLElement | null>(null)
const drag = useReviewDrag(root)
const stamp = useReviewStamp(root, () => !drag.dragging.value)

const showingPaper = computed(() =>
    store.stage === 'prepare' || store.stage === 'stamped',
)

function moveScene(event: PointerEvent) {
    drag.move(event)
    stamp.move(event)
}

function releaseScene(event: PointerEvent) {
    drag.up(event)
    stamp.up(event)
}

function cancelScene() {
    drag.cancel()
    stamp.cancel()
}

function pickReceipt(event: PointerEvent, id: number) {
    if (stamp.dragging.value) return

    drag.start(event, id)
}

function chooseReceipt(id: number) {
    if (stamp.dragging.value) return

    drag.pick(id)
}

function pickStamp(event: PointerEvent) {
    if (drag.dragging.value) return

    drag.cancel()
    stamp.down(event)
}

function transferStamp(event: KeyboardEvent) {
    if (drag.dragging.value) return

    drag.cancel()

    void stamp.transfer(event.currentTarget as HTMLElement)
}

onBeforeUnmount(cancelScene)

</script>

<template>
    <div class="review-overlay">
        <section
            ref="root"
            class="review-scene"
            role="dialog"
            aria-modal="true"
            aria-label="Review business books"
            tabindex="-1"
            @pointermove="moveScene"
            @pointerup="releaseScene"
            @pointercancel="cancelScene"
            @lostpointercapture="drag.cancel"
        >
            <img
                class="review-scene-image"
                :src="reviewImages.scene"
                alt=""
                draggable="false"
            />

            <ReviewReceiptTray
                v-if="store.stage === 'select' || showingPaper"
                :picked-id="drag.pickedId.value"
                :dragging-id="
                    drag.dragging.value ? drag.pickedId.value : null
                "
                @pick="pickReceipt"
                @choose="chooseReceipt"
            />

            <section
                v-if="store.stage === 'select'"
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

                        <div>
                            <dt>Accountant fee</dt>
                            <dd>{{ store.formatMoney(store.fee) }}</dd>
                        </div>

                        <div>
                            <dt>
                                Estimated suspicion
                                <small class="review-summary-note">
                                    With perfect paperwork
                                </small>
                            </dt>

                            <dd class="review-summary-suspicion">
                                <span>
                                    {{
                                        store.formatReduction(
                                            store.payload?.suspicion ?? 0,
                                        )
                                    }}
                                </span>

                                <span
                                    class="review-summary-arrow"
                                    aria-hidden="true"
                                >
                                    →
                                </span>

                                <span>
                                    {{
                                        store.formatReduction(
                                            store.expectedSuspicion,
                                        )
                                    }}
                                </span>
                            </dd>
                        </div>
                    </dl>

                    <p class="review-summary-hint" aria-live="polite">
                        {{ store.selectionHint }}
                    </p>
                </div>

                <button
                    type="button"
                    class="review-paper-button review-prepare-button"
                    :disabled="!store.meetsMinimum"
                    @click="store.prepareBooks"
                >
                    Prepare books
                </button>
            </section>

            <ReviewWorksheet
                v-else-if="showingPaper"
                :over-row-id="drag.overRowId.value"
                :picked-id="drag.pickedId.value"
                :stamp-over="stamp.over.value"
                @place="drag.place"
            />

            <ReviewFolder v-else />

            <ReviewStamp
                v-if="store.canStamp"
                :moving="stamp.dragging.value"
                :x="stamp.x.value"
                :y="stamp.y.value"
                @pick="pickStamp"
                @transfer="transferStamp"
            />

            <div
                v-if="drag.dragging.value && drag.receipt.value"
                class="review-receipt review-receipt-ghost"
                :style="{
                    left: `${drag.x.value}px`,
                    top: `${drag.y.value}px`,
                }"
                aria-hidden="true"
            >
                <ReviewReceiptPaper :receipt="drag.receipt.value" />
            </div>
        </section>
    </div>
</template>