<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

const props = defineProps<{
    value: string
}>()

const container = ref<HTMLSpanElement | null>(null)
const text = ref<HTMLSpanElement | null>(null)

let observer: ResizeObserver | undefined
let previousWidth = 0

function fit() {
    const outer = container.value
    const inner = text.value

    if (!outer || !inner || outer.clientWidth === 0) return

    // Restore the normal size before measuring a new value or width.
    inner.style.removeProperty('font-size')

    const normalSize = Number.parseFloat(
        window.getComputedStyle(inner).fontSize,
    )

    const textWidth = inner.getBoundingClientRect().width
    const availableWidth = outer.clientWidth

    if (textWidth > availableWidth) {
        inner.style.fontSize =
            `${normalSize * availableWidth / textWidth}px`
    }
}

watch(() => props.value, fit, { flush: 'post' })

onMounted(() => {
    observer = new ResizeObserver(() => {
        const width = container.value?.clientWidth ?? 0

        if (width === previousWidth) return

        previousWidth = width
        fit()
    })

    if (container.value) observer.observe(container.value)

    fit()
})

onBeforeUnmount(() => {
    observer?.disconnect()
})
</script>

<template>
    <span ref="container" class="review-amount" :title="value">
        <span ref="text" class="review-amount-value">{{ value }}</span>
    </span>
</template>