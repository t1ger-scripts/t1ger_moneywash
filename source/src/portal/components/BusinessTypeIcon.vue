<script setup lang="ts">
import { computed, type Component } from 'vue'
import {
    Building2,
    CarFront,
    Coffee,
    Dices,
    Fuel,
    Martini,
    Music2,
    Sparkles,
    UtensilsCrossed,
    WashingMachine,
} from '@lucide/vue'

const props = withDefaults(
    defineProps<{
        businessType: string
        size?: number
        strokeWidth?: number
    }>(),
    {
        size: 24,
        strokeWidth: 2,
    },
)

const businessTypeIcons: Readonly<Record<string, Component>> = {
    coffee_shop: Coffee,
    gas_station: Fuel,
    restaurant: UtensilsCrossed,
    laundromat: WashingMachine,
    bar: Martini,
    nightclub: Music2,
    stripclub: Sparkles,
    carwash: CarFront,
    casino: Dices,
}

const selectedIcon = computed(
    () => businessTypeIcons[props.businessType] ?? Building2,
)
</script>

<template>
    <component
        :is="selectedIcon"
        :size="size"
        :stroke-width="strokeWidth"
        aria-hidden="true"
    />
</template>