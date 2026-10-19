<script setup lang="ts">
import { computed } from 'vue'
import {
    raidImages,
    safePilePosition,
} from '../utils/raid.utils'

const props = withDefaults(
    defineProps<{
        count?: number
    }>(),
    {
        count: 10,
    },
)

const pileCount = computed(() => {
    const count = Number.isFinite(props.count)
        ? Math.floor(props.count)
        : 10

    return Math.max(1, Math.min(20, count))
})
</script>

<template>
    <div class="raid-cash-stacks" aria-hidden="true">
        <span
            v-for="index in pileCount"
            :key="index"
            class="raid-cash-bundle"
            :style="safePilePosition(index - 1, pileCount)"
        >
            <img
                :src="raidImages.bundle"
                alt=""
                draggable="false"
            />
        </span>
    </div>
</template>