import {
    computed,
    onBeforeUnmount,
    ref,
    watch,
    type Ref,
} from 'vue'
import { useReviewStore } from '../stores/review.store'

export function useReviewDrag(root: Ref<HTMLElement | null>) {
    const store = useReviewStore()

    const pickedId = ref<number | null>(null)
    const dragging = ref(false)
    const overRowId = ref<number | null>(null)
    const x = ref(0)
    const y = ref(0)

    let pointer: number | null = null
    let source: HTMLElement | null = null

    const receipt = computed(() =>
        store.selectedReceipts.find(
            (item) => item.id === pickedId.value,
        ) ?? null,
    )

    function cancel() {
        const previousPointer = pointer
        const previousSource = source

        pointer = null
        source = null
        dragging.value = false
        pickedId.value = null
        overRowId.value = null

        if (
            previousPointer !== null &&
            previousSource?.hasPointerCapture(previousPointer)
        ) {
            previousSource.releasePointerCapture(previousPointer)
        }
    }

    function pick(id: number) {
        cancel()

        if (store.stage !== 'prepare') return
        if (!store.selectedIds.includes(id)) return

        pickedId.value = id
    }

    function move(event: PointerEvent) {
        if (
            pointer !== event.pointerId ||
            !dragging.value ||
            !root.value
        ) return

        const bounds = root.value.getBoundingClientRect()

        x.value = event.clientX - bounds.left
        y.value = event.clientY - bounds.top

        const element = document.elementFromPoint(
            event.clientX,
            event.clientY,
        )

        const row = element?.closest<HTMLElement>('[data-review-row]')

        overRowId.value = row && root.value.contains(row)
            ? Number(row.dataset.reviewRow)
            : null
    }

    function start(event: PointerEvent, id: number) {
        if (event.button !== 0 || dragging.value) return

        pick(id)

        if (pickedId.value === null) return

        event.preventDefault()

        pointer = event.pointerId
        source = event.currentTarget as HTMLElement
        source.setPointerCapture(event.pointerId)

        dragging.value = true
        move(event)
    }

    function place(entryId: number) {
        const id = pickedId.value

        if (id === null) return

        store.assignReceipt(entryId, id)
        cancel()
    }

    function up(event: PointerEvent) {
        if (pointer !== event.pointerId) return

        move(event)

        const entryId = overRowId.value

        if (entryId !== null) {
            place(entryId)
        } else {
            cancel()
        }
    }

    watch(() => store.stage, cancel)
    watch(() => store.sheetPage, cancel)

    onBeforeUnmount(cancel)

    return {
        pickedId,
        dragging,
        overRowId,
        receipt,
        x,
        y,
        start,
        pick,
        move,
        up,
        place,
        cancel,
    }
}