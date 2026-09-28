<script setup lang="ts">
defineProps<{
    value: string
    displayState: string
    feederLabel: string
    running: boolean
    over: boolean
}>()
</script>
<template>
    <div class="counter-machine" :class="{ 'is-running': running }">
        <div
            class="counter-feeder"
            :class="{ 'is-over': over }"
            data-cash-feeder
        >
            {{ feederLabel }}
        </div>
        <div class="counter-housing">
            <div class="counter-brand">T1GER / CASH COUNTER</div>
            <div class="counter-display">
                <small>{{ displayState }}</small>
                <div>{{ value }}</div>
            </div>
            <div class="counter-keys" aria-hidden="true">
                <span>UV</span><span>MODE</span><span>BATCH</span
                ><span>AUTO</span>
            </div>
            <div class="counter-slot" aria-hidden="true">
                <span class="counter-moving-note" />
            </div>
        </div>
    </div>
</template>
