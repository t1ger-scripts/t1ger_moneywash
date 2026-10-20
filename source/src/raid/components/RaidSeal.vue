<script setup lang="ts">
import { computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useSlideSeal } from '@/shared/composables/useSlideSeal'

const props = defineProps<{
    sealed: boolean
    busy: boolean
}>()

const emit = defineEmits<{
    complete: []
}>()

const { t } = useI18n()

const {
    progress,
    down,
    move,
    up,
    cancel,
    finish,
} = useSlideSeal(
    () => !props.sealed && !props.busy,
    () => emit('complete'),
)

// The server refused the seal: put the handle back at the start.
watch(
    () => props.busy,
    (busy, wasBusy) => {
        if (wasBusy && !busy && !props.sealed) cancel()
    },
)

const text = computed(() => {
    if (props.sealed) return t('raid.evidenceSecured')
    if (props.busy) return t('raid.securing')

    return t('raid.slideToSecure')
})
</script>

<template>
    <button
        class="raid-seal"
        :class="{ 'raid-seal--complete': sealed }"
        :style="{
            '--seal-progress': sealed
                ? '100%'
                : `${progress * 100}%`,
        }"
        :disabled="sealed"
        :aria-label="t('raid.sealAria')"
        @pointerdown="down"
        @pointermove="move"
        @pointerup="up"
        @pointercancel="cancel"
        @keydown.enter.prevent="finish"
        @keydown.space.prevent="finish"
    >
        <span class="raid-seal-text">
            {{ text }}
        </span>

        <span
            v-if="!sealed"
            class="raid-seal-handle"
            :style="{ left: `${6 + progress * 88}%` }"
            aria-hidden="true"
        >
            →
        </span>
    </button>
</template>