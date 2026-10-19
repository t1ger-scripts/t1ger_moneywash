import { onBeforeUnmount, ref, type Ref } from 'vue'
import { useSceneDrag } from '@/shared/composables/useSceneDrag'
import { useRaidStore } from '../stores/raid.store'

export function useRaidDrag(root: Ref<HTMLElement | null>) {
    const store = useRaidStore()
    const selectedPileId = ref<number | null>(null)

    const drag = useSceneDrag(
        root,
        () => !store.allPacked,
        () => {
            const id = selectedPileId.value

            if (id === null) return false

            return store.packPile(id)
        },
        '[data-raid-mouth]',
        '[data-raid-cash]',
    )

    function pickPile(event: PointerEvent, id: number) {
        if (drag.dragging.value || store.allPacked) return

        selectedPileId.value = id
        drag.down(event)
    }

    function keyboardPack(event: KeyboardEvent, id: number) {
        if (drag.dragging.value || store.allPacked) return

        selectedPileId.value = id

        void drag.transfer(
            event.currentTarget as HTMLElement,
        )
    }

    onBeforeUnmount(() => {
        drag.cancel()
        selectedPileId.value = null
    })

    return {
        drag,
        selectedPileId,
        pickPile,
        keyboardPack,
    }
}