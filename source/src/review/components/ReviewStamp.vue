<script setup lang="ts">
import { reviewImages } from '../utils/review.utils'
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

defineProps<{
    moving: boolean
    x: number
    y: number
}>()

const emit = defineEmits<{
    pick: [event: PointerEvent]
    transfer: [event: KeyboardEvent]
}>()
</script>

<template>
    <button
        type="button"
        class="review-stamp-button"
        :class="{ 'is-moving': moving }"
        data-review-stamp
        :aria-label="t('review.stamp.aria')"
        @pointerdown="emit('pick', $event)"
        @keydown.enter.prevent="emit('transfer', $event)"
        @keydown.space.prevent="emit('transfer', $event)"
    >
        <img
            class="review-stamp-art"
            :src="reviewImages.stamp"
            alt=""
            draggable="false"
        />

        <span class="review-stamp-caption">{{ t('review.stampToCommit') }}</span>
    </button>

    <div
        v-if="moving"
        class="review-stamp-ghost"
        :style="{ left: `${x}px`, top: `${y}px` }"
        aria-hidden="true"
    >
        <img
            class="review-stamp-art"
            :src="reviewImages.stamp"
            alt=""
            draggable="false"
        />
    </div>
</template>