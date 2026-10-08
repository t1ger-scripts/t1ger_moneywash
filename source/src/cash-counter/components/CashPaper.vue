<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
    defineProps<{
        fill?: number
        banded?: boolean
    }>(),
    {
        fill: 1,
        banded: false,
    },
)

const density = computed(() =>
    Math.max(0, Math.min(1, props.fill)),
)

const imageUrl = computed(() =>
    `${import.meta.env.BASE_URL}images/cash-counter/${
        props.banded ? 'bundle.png' : 'loose-stack.png'
    }`,
)

/*
 * Keep the printed top face intact.
 * Only the paper-edge section changes thickness.
 */
const faceStyle = computed(() => ({
    transform: `translateY(${24 * (1 - density.value)}%)`,
}))

const edgeStyle = computed(() => ({
    transform: `scaleY(${density.value})`,
}))
</script>

<template>
    <span
        class="cash-paper"
        :style="{ opacity: density > 0 ? 1 : 0 }"
        aria-hidden="true"
    >
        <span
            class="cash-paper-part cash-paper-part--edges"
            :style="edgeStyle"
        >
            <span class="cash-paper-art">
                <img
                    :src="imageUrl"
                    alt=""
                    draggable="false"
                />
            </span>
        </span>

        <span
            class="cash-paper-part cash-paper-part--face"
            :style="faceStyle"
        >
            <span class="cash-paper-art">
                <img
                    :src="imageUrl"
                    alt=""
                    draggable="false"
                />
            </span>
        </span>
    </span>
</template>