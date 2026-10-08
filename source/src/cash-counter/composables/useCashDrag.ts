import { ref, type Ref } from 'vue'

export function useCashDrag(
    root: Ref<HTMLElement | null>,
    enabled: () => boolean,
    submit: () => void,
    targetSelector = '[data-cash-feeder]',
) {
    const dragging = ref(false)
    const over = ref(false)
    const x = ref(0)
    const y = ref(0)

    let pointer: number | null = null
    let source: HTMLElement | null = null

    function cancel() {
        const previousPointer = pointer
        const previousSource = source

        pointer = null
        source = null
        dragging.value = false
        over.value = false

        if (
            previousPointer !== null &&
            previousSource?.hasPointerCapture(previousPointer)
        ) {
            previousSource.releasePointerCapture(previousPointer)
        }
    }

    function move(event: PointerEvent) {
        if (pointer !== event.pointerId || !root.value) return

        const origin = root.value.getBoundingClientRect()

        x.value = event.clientX - origin.left + root.value.scrollLeft
        y.value = event.clientY - origin.top + root.value.scrollTop

        const target = root.value
            .querySelector(targetSelector)
            ?.getBoundingClientRect()

        over.value =
            !!target &&
            event.clientX >= target.left &&
            event.clientX <= target.right &&
            event.clientY >= target.top &&
            event.clientY <= target.bottom
    }

    function down(event: PointerEvent) {
        if (
            !enabled() ||
            event.button !== 0 ||
            pointer !== null
        ) return

        event.preventDefault()

        pointer = event.pointerId
        source = event.currentTarget as HTMLElement
        source.setPointerCapture(event.pointerId)
        dragging.value = true

        move(event)
    }

    function up(event: PointerEvent) {
        if (pointer !== event.pointerId) return

        move(event)
        const accepted = over.value && enabled()
        cancel()

        if (accepted) submit()
    }

    return { dragging, over, x, y, down, move, up, cancel }
}