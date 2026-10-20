<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import {
    raidImages,
    createSafePileLayout,
} from '../utils/raid.utils'

const props = defineProps<{
    piles: number[]
    unavailableIds: number[]
    selectedId: number | null
    dragging: boolean
    format: (amount: number) => string
}>()

const emit = defineEmits<{
    pick: [event: PointerEvent, id: number]
    transfer: [event: KeyboardEvent, id: number]
}>()

const { t } = useI18n()

const visiblePiles = computed(() =>
    createSafePileLayout(
        props.piles.length,
        props.unavailableIds,
    ),
)
</script>

<template>
    <div class="raid-cash-stacks">
        <template v-for="pile in visiblePiles" :key="pile.id">
            <button
                class="raid-cash-bundle"
                data-raid-cash
                :style="pile.style"
                :class="{
                    'raid-cash-bundle--held':
                        dragging && selectedId === pile.id,
                }"
                :aria-label="t('raid.bagPile', { amount: format(piles[pile.id]) })"
                @pointerdown="emit('pick', $event, pile.id)"
                @keydown.enter.prevent="emit('transfer', $event, pile.id)"
                @keydown.space.prevent="emit('transfer', $event, pile.id)"
            >
                <span class="raid-cash-art" aria-hidden="true">
                    <img
                        :src="raidImages.bundle"
                        alt=""
                        draggable="false"
                    />
                </span>
            </button>

            <span
                v-if="!dragging"
                class="raid-cash-amount"
                :style="{
                    left: pile.style.left,
                    bottom:
                        `calc(${pile.style.bottom} + var(--raid-cash-height) + 0.4%)`,
                }"
                aria-hidden="true"
            >
                {{ format(piles[pile.id]) }}
            </span>
        </template>
    </div>
</template>