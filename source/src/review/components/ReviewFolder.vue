<script setup lang="ts">
import { useSlideSeal } from '@/shared/composables/useSlideSeal'
import { useReviewStore } from '../stores/review.store'
import { reviewImages } from '../utils/review.utils'

const store = useReviewStore()

const {
    progress,
    down,
    move,
    up,
    cancel,
    finish,
} = useSlideSeal(
    () => store.stage === 'folder',
    store.sealFolder,
)
</script>

<template>
    <section
        class="review-folder"
        :class="{ 'is-complete': store.stage === 'complete' }"
        aria-label="Accountant folder"
    >
        <img
            class="review-folder-art review-folder-open"
            :src="reviewImages.folderOpen"
            alt=""
            draggable="false"
        />

        <img
            class="review-folder-art review-folder-closed"
            :src="reviewImages.folderClosed"
            alt=""
            draggable="false"
        />

        <div
            v-if="store.stage === 'folder'"
            class="review-folder-papers"
        >
            <img
                :src="reviewImages.worksheet"
                alt=""
                draggable="false"
            />

            <div>
                <strong>Prepared books</strong>
                <span>{{ store.payload?.businessName }}</span>
                <span>{{ store.entries.length }} receipts enclosed</span>
            </div>
        </div>

        <button
            v-if="store.stage === 'folder'"
            type="button"
            class="review-folder-seal"
            aria-label="Slide to seal the accountant folder"
            @pointerdown="down"
            @pointermove="move"
            @pointerup="up"
            @pointercancel="cancel"
            @keydown.enter.prevent="finish"
            @keydown.space.prevent="finish"
        >
            <span>Slide to seal</span>

            <span
                class="review-folder-seal-handle"
                :style="{ left: `${6 + progress * 88}%` }"
                aria-hidden="true"
            >
                →
            </span>
        </button>

        <div
            v-if="store.stage === 'complete' && store.result"
            class="review-folder-label"
            aria-live="polite"
        >
            <h2>Ready for delivery</h2>

            <dl>
                <div>
                    <dt>Paperwork quality</dt>
                    <dd>
                        {{ store.formatReduction(store.result.quality * 100) }}%
                    </dd>
                </div>

                <div>
                    <dt>Reduction</dt>
                    <dd>
                        {{ store.formatReduction(store.result.reduction) }}
                    </dd>
                </div>

                <div>
                    <dt>After delivery</dt>
                    <dd>
                        {{
                            store.formatReduction(
                                store.result.suspicionBefore,
                            )
                        }}
                        →
                        {{
                            store.formatReduction(
                                store.result.suspicionAfter,
                            )
                        }}
                    </dd>
                </div>

                <div>
                    <dt>Fee due</dt>
                    <dd>{{ store.formatMoney(store.result.fee) }}</dd>
                </div>
            </dl>

            <p>
                {{ store.result.mistakes }} / {{ store.result.rows }}
                rows incorrect
            </p>

            <button
                type="button"
                class="review-paper-button"
                @click="store.dismiss"
            >
                Finish preview
            </button>
        </div>
    </section>
</template>