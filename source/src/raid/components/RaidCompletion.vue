<script setup lang="ts">
import { formatRaidMoney } from '../utils/raid.utils'

defineProps<{
    amount: number
}>()

const emit = defineEmits<{
    restart: []
}>()
</script>

<template>
    <div class="raid-completion" role="status">
        <span class="raid-completion-icon" aria-hidden="true">
            ✓
        </span>

        <strong>Cash secured</strong>

        <p>
            {{ formatRaidMoney(amount) }} collected as evidence
        </p>

        <button
            class="raid-restart"
            @click="emit('restart')"
        >
            Restart preview
        </button>
    </div>
</template>