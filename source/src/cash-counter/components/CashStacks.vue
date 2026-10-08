<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { CashPile } from '../cash-counter.types'
import {
    cashCounterImages,
    cashPilePosition,
} from '../utils/cash-counter.utils'

const props = withDefaults(
    defineProps<{
        items?: CashPile[]
        totalSlots?: number
        compact?: boolean
        lifted?: boolean
        liftedId?: number | null
        interactive?: boolean
        disabled?: boolean
        format?: (amount: number) => string
    }>(),
    {
        items: () => [],
        totalSlots: 10,
        compact: false,
        lifted: false,
        liftedId: null,
        interactive: false,
        disabled: false,
    },
)

const emit = defineEmits<{
    pick: [event: PointerEvent, id: number]
    move: [event: PointerEvent]
    release: [event: PointerEvent]
    cancel: []
    load: [id: number]
}>()

const { t } = useI18n()

const items = computed<CashPile[]>(() =>
    props.compact
        ? [{ id: -1, amount: 0, slot: 0 }]
        : props.items,
)

function formatAmount(amount: number) {
    return props.format?.(amount) ?? String(amount)
}
</script>

<template>
    <span
        class="cash-stacks"
        :class="{
            'cash-stacks--compact': compact,
            'cash-stacks--interactive': interactive,
        }"
    >
        <component
            :is="interactive ? 'button' : 'span'"
            v-for="pile in items"
            :key="pile.id"
            class="cash-bundle"
            :class="{
                'is-lifted': lifted || liftedId === pile.id,
            }"
            :style="compact
                ? undefined
                : cashPilePosition(pile.slot, totalSlots)"
            :type="interactive ? 'button' : undefined"
            :disabled="interactive ? disabled : undefined"
            :data-pile-id="pile.id"
            :aria-label="interactive
                ? t('cashCounter.loadPile', {
                    amount: formatAmount(pile.amount),
                })
                : undefined"
            @pointerdown="interactive && emit('pick', $event, pile.id)"
            @pointermove="interactive && emit('move', $event)"
            @pointerup="interactive && emit('release', $event)"
            @pointercancel="interactive && emit('cancel')"
            @keydown.enter.prevent="interactive && !disabled && emit('load', pile.id)"
            @keydown.space.prevent="interactive && !disabled && emit('load', pile.id)"
        >
            <img
                :src="cashCounterImages.pile"
                alt=""
                draggable="false"
            />

            <span
                v-if="!compact"
                class="counter-pile-value"
                aria-hidden="true"
            >
                {{ formatAmount(pile.amount) }}
            </span>
        </component>
    </span>
</template>