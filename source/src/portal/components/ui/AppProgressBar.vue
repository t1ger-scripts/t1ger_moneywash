<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
    defineProps<{
        value: number
        maximum?: number
        label: string
    }>(),
    {
        maximum: 100,
    },
)

const percentage = computed(() => {
    if (props.maximum <= 0) {
        return 0
    }

    const calculatedPercentage =
        (props.value / props.maximum) * 100

    return Math.min(
        100,
        Math.max(0, calculatedPercentage),
    )
})
</script>

<template>
    <div class="app-progress" role="progressbar" :aria-label="label" :aria-valuenow="value" aria-valuemin="0"
        :aria-valuemax="maximum">
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