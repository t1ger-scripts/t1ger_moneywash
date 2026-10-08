<script setup lang="ts">
import { computed } from 'vue'
import {
    cashCounterImages,
    cashPilePosition,
} from '../utils/cash-counter.utils'

const props = withDefaults(
    defineProps<{
        count?: number
        compact?: boolean
        lifted?: boolean
    }>(),
    {
        count: 0,
        compact: false,
        lifted: false,
    },
)

const count = computed(() =>
    props.compact ? 1 : Math.max(0, props.count),
)
</script>

<template>
    <span
        class="cash-stacks"
        :class="{ 'cash-stacks--compact': compact }"
        aria-hidden="true"
    >
        <span
            v-for="i in count"
            :key="i"
            class="cash-bundle"
            :class="{ 'is-lifted': lifted && i === count }"
            :style="compact ? undefined : cashPilePosition(i - 1)"
        >
            <img
                :src="cashCounterImages.pile"
                alt=""
                draggable="false"
            />
        </span>
    </span>
</template>