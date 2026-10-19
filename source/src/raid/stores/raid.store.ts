import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { splitRaidCash } from '../utils/raid.utils'

export const useRaidStore = defineStore('raid', () => {
    const amount = ref(125000)
    const stackCount = ref(10)
    const packedIds = ref<number[]>([])
    const sealed = ref(false)

    const piles = computed(() =>
        splitRaidCash(amount.value, stackCount.value),
    )

    const packedAmount = computed(() =>
        packedIds.value.reduce(
            (total, id) => total + (piles.value[id] ?? 0),
            0,
        ),
    )

    const remainingAmount = computed(() =>
        amount.value - packedAmount.value,
    )

    const allPacked = computed(() =>
        piles.value.length > 0 &&
        packedIds.value.length === piles.value.length,
    )

    function packPile(id: number): boolean {
        if (
            sealed.value ||
            !Number.isInteger(id) ||
            id < 0 ||
            id >= piles.value.length ||
            packedIds.value.includes(id)
        ) return false

        packedIds.value.push(id)

        return true
    }

    function sealBag(): boolean {
        if (!allPacked.value || sealed.value) return false

        sealed.value = true

        return true
    }

    function reset() {
        packedIds.value = []
        sealed.value = false
    }

    return {
        amount,
        stackCount,
        piles,
        packedIds,
        packedAmount,
        remainingAmount,
        allPacked,
        sealed,
        packPile,
        sealBag,
        reset,
    }
})