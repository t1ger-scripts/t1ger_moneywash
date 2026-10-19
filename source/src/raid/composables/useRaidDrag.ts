import { onBeforeUnmount, ref, type Ref } from 'vue'
import { useSceneDrag } from '@/shared/composables/useSceneDrag'
import { useRaidStore } from '../stores/raid.store'
import { isRaidBagDropPoint } from '../utils/raid.utils'

export function useRaidDrag(root: Ref<HTMLElement | null>) {
    const store = useRaidStore()

    const selectedPileId = ref<number | null>(null)
    const depositing = ref(false)

    let depositAnimation: Animation | null = null
    let disposed = false

    async function depositPile(): Promise<boolean> {
        const id = selectedPileId.value

        if (
            id === null ||
            disposed ||
            store.packedIds.includes(id)
        ) return false

        const preview = root.value?.querySelector<HTMLElement>(
            '[data-raid-drag-preview]',
        )

        if (!preview) return false

        depositing.value = true

        const reducedMotion = window.matchMedia(
            '(prefers-reduced-motion: reduce)',
        ).matches

        const animation = preview.animate(
            [
                {
                    transform:
                        'translate(-50%, -50%) rotate(-2deg) scale(1)',
                    opacity: 1,
                },
                {
                    offset: 0.4,
                    opacity: 0.8,
                },
                {
                    transform:
                        'translate(-50%, 70%) rotate(5deg) scale(0.85)',
                    opacity: 0,
                },
            ],
            {
                duration: reducedMotion ? 0 : 450,
                easing: 'cubic-bezier(0.4, 0, 0.8, 1)',
                fill: 'forwards',
            },
        )

        depositAnimation = animation

        try {
            await animation.finished

            if (disposed) return false

            // Update the label and settle the safe pile only
            // after the bundle has disappeared into the bag.
            return store.packPile(id)
        } catch {
            return false
        } finally {
            animation.cancel()

            if (depositAnimation === animation) {
                depositAnimation = null
            }

            depositing.value = false
        }
    }

    const drag = useSceneDrag(
        root,
        () => !store.allPacked,
        depositPile,
        '[data-raid-mouth]',
        '[data-raid-cash]',
        isRaidBagDropPoint,
    )

    function pickPile(event: PointerEvent, id: number) {
        if (
            drag.dragging.value ||
            depositing.value ||
            store.allPacked
        ) return

        selectedPileId.value = id
        drag.down(event)
    }

    function keyboardPack(event: KeyboardEvent, id: number) {
        if (
            drag.dragging.value ||
            depositing.value ||
            store.allPacked
        ) return

        selectedPileId.value = id

        void drag.transfer(
            event.currentTarget as HTMLElement,
        )
    }

    onBeforeUnmount(() => {
        disposed = true
        depositAnimation?.cancel()
        drag.cancel()
        selectedPileId.value = null
    })

    return {
        drag,
        depositing,
        selectedPileId,
        pickPile,
        keyboardPack,
    }
}