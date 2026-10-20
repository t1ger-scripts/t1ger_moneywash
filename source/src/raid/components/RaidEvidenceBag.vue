<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import RaidSeal from './RaidSeal.vue'

defineProps<{
    packedAmount: number
    dragging: boolean
    over: boolean
    allPacked: boolean
    sealed: boolean
    busy: boolean
    format: (amount: number) => string
}>()

const emit = defineEmits<{
    seal: []
}>()

const { t } = useI18n()
</script>

<template>
    <div
        v-if="!allPacked"
        class="raid-bag-mouth"
        data-raid-mouth
        :class="{
            'raid-bag-mouth--active': dragging,
            'raid-bag-mouth--over': over,
        }"
    >
        <svg
            class="raid-bag-outline"
            viewBox="0 0 1000 400"
            preserveAspectRatio="none"
            aria-hidden="true"
        >
            <path
                data-raid-drop-shape
                d="
                    M 14 140
                    C 55 60, 220 5, 390 10
                    C 650 5, 890 65, 978 185
                    C 1005 225, 830 310, 590 318
                    C 350 330, 95 263, 14 172
                    Q 4 150, 14 140
                    Z
                "
                vector-effect="non-scaling-stroke"
            />
        </svg>

        <span v-if="dragging" class="raid-bag-hint">
            {{ over ? t('raid.releaseToBag') : t('raid.dropHere') }}
        </span>
    </div>

    <div class="raid-evidence-label" aria-live="polite">
        <span>{{ t('raid.evidenceLabel') }}</span>

        <strong>{{ format(packedAmount) }}</strong>
    </div>

    <RaidSeal
        v-if="allPacked"
        :sealed="sealed"
        :busy="busy"
        @complete="emit('seal')"
    />
</template>