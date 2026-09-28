<script setup lang="ts">
import { computed } from 'vue'
import { stackCount } from '../cash-counter.utils'
const props = withDefaults(
    defineProps<{ amount: number; compact?: boolean }>(),
    { compact: false },
)
const count = computed(() => (props.compact ? 1 : stackCount(props.amount)))
function position(i: number) {
    const layer = Math.floor(i / 2)
    return {
        '--x': `${(i % 2) * 68 + 9 + (layer % 2 ? 4 : 0)}px`,
        '--y': `${16 + layer * 26}px`,
        '--turn': `${(i % 2 ? 8 : -10) + ((layer % 3) - 1) * 4}deg`,
        '--layer': i + 1,
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
            :style="position(i - 1)"
        />
    </span>
</template>
