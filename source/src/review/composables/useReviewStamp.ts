import { onBeforeUnmount, watch, type Ref } from 'vue'
import { useSceneDrag } from '@/shared/composables/useSceneDrag'
import { useReviewStore } from '../stores/review.store'

export function useReviewStamp(
    root: Ref<HTMLElement | null>,
    available: () => boolean,
) {
    const store = useReviewStore()

    const drag = useSceneDrag(
        root,
        () => store.canStamp && available(),
        store.stampBooks,
        '[data-review-stamp-target]',
        '[data-review-stamp]',
    )

    watch(() => store.stage, () => drag.cancel())

    onBeforeUnmount(() => drag.cancel())

    return drag
}