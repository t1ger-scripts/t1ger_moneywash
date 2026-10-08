<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
    modelValue: number
    available: number
    disabled: boolean
    format: (n: number) => string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: number] }>()
const { t } = useI18n()
const editing = ref(false)
const text = ref(props.format(props.modelValue))

watch(
    () => props.modelValue,
    (value) => {
        text.value = editing.value ? String(value) : props.format(value)
    },
)
const percent = computed(() =>
    props.available
        ? Math.sqrt(Math.min(1, props.modelValue / props.available)) * 100
        : 0,
)
function moveSlider(event: Event) {
    const position = Number((event.target as HTMLInputElement).value)
    const amount = position === 0
        ? 0
        : Math.max(1, Math.round(props.available * (position / 1000) ** 2))
    emit('update:modelValue', amount)
}
function typeAmount(event: Event) {
    const input = event.target as HTMLInputElement
    const digits = input.value.replace(/[^\d]/g, '')
    input.value = digits
    text.value = digits
    emit('update:modelValue', Number(digits))
}
function focusAmount() {
    editing.value = true
}
function blurAmount() {
    editing.value = false
    text.value = props.format(props.modelValue)
}
</script>
<template>
    <div class="counter-controls">
        <div class="counter-selection">
            <span>{{ t('cashCounter.amount') }}</span>
            <input
                id="cash-amount-input"
                class="counter-amount-input"
                type="text"
                inputmode="numeric"
                autocomplete="off"
                :aria-label="t('cashCounter.amount')"
                :aria-invalid="modelValue > available"
                :value="text"
                :disabled="disabled"
                @input="typeAmount"
                @focus="focusAmount"
                @blur="blurAmount"
            />
        </div>
        <input
            id="cash-amount-slider"
            class="counter-slider"
            type="range"
            min="0"
            max="1000"
            step="1"
            :value="Math.round(percent * 10)"
            :style="{ '--fill': percent + '%' }"
            :disabled="disabled || available <= 0"
            :aria-label="t('cashCounter.amount')"
            :aria-valuetext="format(modelValue)"
            @input="moveSlider"
        />
        <div class="counter-range-labels">
            <span>{{ format(0) }}</span
            ><span>{{ format(available / 4) }}</span
            ><span>{{ format(available) }}</span>
        </div>
    </div>
</template>
