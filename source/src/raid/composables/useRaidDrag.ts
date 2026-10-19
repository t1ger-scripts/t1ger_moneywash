import {
    computed,
    onBeforeUnmount,
    ref,
    type Ref,
} from 'vue'
import { useSceneDrag } from '@/shared/composables/useSceneDrag'
import { useRaidStore } from '../stores/raid.store'
import { isRaidBagDropPoint } from '../utils/raid.utils'
import type { RaidDeposit } from '../raid.types'

export function useRaidDrag(root: Ref<HTMLElement | null>) {
    const store = useRaidStore()

    const selectedPileId = ref<number | null>(null)
    const deposits = ref<RaidDeposit[]>([])

    // Depositing bundles leave the safe immediately,
    // but enter the label totals only after fading out.
    const unavailableIds = computed(() => [
        ...store.packedIds,
        ...deposits.value.map(deposit => deposit.id),
    ])

    const canPick = computed(() =>
        !store.sealed &&
        unavailableIds.value.length < store.piles.length,
    )

    function queueDeposit(): boolean {
        const id = selectedPileId.value
        const bounds = root.value?.getBoundingClientRect()

        if (
            id === null ||
            !bounds ||
            bounds.width <= 0 ||
            bounds.height <= 0 ||
            unavailableIds.value.includes(id)
        ) return false

        deposits.value.push({
            id,
            x: drag.x.value / bounds.width * 100,
            y: drag.y.value / bounds.height * 100,
        })

        return true
    }

    const drag = useSceneDrag(
        root,
        () => canPick.value,
        queueDeposit,
        '[data-raid-mouth]',
        '[data-raid-cash]',
        isRaidBagDropPoint,
    )

    function finishDeposit(id: number) {
        const exists = deposits.value.some(
            deposit => deposit.id === id,
        )

        if (!exists) return

        store.packPile(id)

        deposits.value = deposits.value.filter(
            deposit => deposit.id !== id,
        )
    }

    function pickPile(event: PointerEvent, id: number) {
        if (
            drag.dragging.value ||
            !canPick.value ||
            unavailableIds.value.includes(id)
        ) return

        selectedPileId.value = id
        drag.down(event)
    }

    function keyboardPack(event: KeyboardEvent, id: number) {
        if (
            drag.dragging.value ||
            !canPick.value ||
            unavailableIds.value.includes(id)
        ) return

        selectedPileId.value = id

        void drag.transfer(
            event.currentTarget as HTMLElement,
        )
    }

    onBeforeUnmount(() => {
        drag.cancel()
        deposits.value = []
        selectedPileId.value = null
    })

    return {
        drag,
        deposits,
        unavailableIds,
        selectedPileId,
        pickPile,
        keyboardPack,
        finishDeposit,
    }
}