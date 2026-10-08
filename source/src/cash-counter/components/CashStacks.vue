<script setup lang="ts">
import { computed, ref } from 'vue'
import { cashCounterImages } from '../utils/cash-counter.utils'

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

const imageFailed = ref(false)

const count = computed(() =>
    props.compact ? 1 : Math.max(0, props.count),
)

function position(index: number) {
    return {
        '--x': `${9 + (index % 2) * 77}px`,
        '--y': `${16 + Math.floor(index / 2) * 19}px`,
        '--turn': `${index % 2 ? 4 : -5}deg`,
        '--layer': index + 1,
    }
}
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
            :class="{
                'has-image': !imageFailed,
                'is-lifted': lifted && i === count,
            }"
            :style="position(i - 1)"
        >
            <img
                v-if="!imageFailed"
                :src="cashCounterImages.pile"
                alt=""
                draggable="false"
                @error="imageFailed = true"
            />
        </span>
    </span>
</template>