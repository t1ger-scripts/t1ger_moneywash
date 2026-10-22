<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
    /** Percentage, 0 to 100. Values outside the range are clamped. */
    value: number
    label: string
}>()

const percentage = computed(() => Math.min(100, Math.max(0, props.value)))
</script>

<template>
    <div class="app-progress" role="progressbar" :aria-label="label" :aria-valuenow="percentage" aria-valuemin="0"
        aria-valuemax="100">
        <span class="app-progress__value" :style="{ width: `${percentage}%` }" />
    </div>
</template>

<style scoped lang="scss">
.app-progress {
    width: 100%;
    height: 0.375rem;
    overflow: hidden;
    border-radius: var(--radius-pill);
    background: var(--color-border);

    &__value {
        display: block;
        height: 100%;
        border-radius: inherit;
        background: var(--color-primary);
        transition:
            width var(--duration-normal) var(--ease-standard);
    }
}
</style>