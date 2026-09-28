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
        ? Math.min(100, (props.modelValue / props.available) * 100)
        : 0,
)

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
            <input id="cash-amount-input" class="counter-amount-input" type="text" inputmode="numeric"
                :aria-label="t('cashCounter.amount')" :aria-invalid="modelValue > available" autocomplete="off"
                :value="text" :disabled="disabled" @input="typeAmount" @focus="focusAmount" @blur="blurAmount" />
        </div>

        <input id="cash-amount-slider" class="counter-slider" type="range" min="0" max="1000" step="1"
            :value="Math.round(percent * 10)" :style="{ '--fill': percent + '%' }"
            :disabled="disabled || available <= 0" :aria-label="t('cashCounter.amount')"
            :aria-valuetext="format(modelValue)" @input="
                emit(
                    'update:modelValue',
                    Math.round(
                        (available *
                            Number(($event.target as HTMLInputElement).value)) /
                        1000,
                    ),
                )
                " />

        <div class="counter-range-labels">
            <span>{{ format(0) }}</span>
            <span>{{ format(available / 2) }}</span>
            <span>{{ format(available) }}</span>
        </div>
    </div>
</template>