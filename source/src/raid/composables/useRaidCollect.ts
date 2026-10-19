import { onBeforeUnmount, type Ref } from 'vue'
import { useSceneDrag } from '@/shared/composables/useSceneDrag'
import { useRaidStore } from '../stores/raid.store'

export function useRaidCollect(root: Ref<HTMLElement | null>) {
    const store = useRaidStore()

    const collectDrag = useSceneDrag(
        root,
        () => store.sealed && !store.collected,
        () => store.collectBag(),
        '[data-raid-collect]',
        '[data-raid-bag]',
    )

    function keyboardCollect(event: KeyboardEvent) {
        void collectDrag.transfer(
            event.currentTarget as HTMLElement,
        )
    }

    onBeforeUnmount(collectDrag.cancel)

    return {
        collectDrag,
        keyboardCollect,
    }
}