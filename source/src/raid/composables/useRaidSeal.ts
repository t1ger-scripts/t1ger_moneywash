import { onBeforeUnmount, ref } from 'vue'

export function useRaidSeal(
    enabled: () => boolean,
    complete: () => void,
) {
    const progress = ref(0)

    let pointerId: number | null = null
    let element: HTMLElement | null = null

    function releasePointer() {
        const previousElement = element
        const previousPointer = pointerId

        element = null
        pointerId = null

        if (
            previousPointer !== null &&
            previousElement?.hasPointerCapture(previousPointer)
        ) {
            previousElement.releasePointerCapture(previousPointer)
        }
    }

    function cancel() {
        releasePointer()
        progress.value = 0
    }

    function move(event: PointerEvent) {
        if (
            !enabled() ||
            pointerId !== event.pointerId ||
            !element
        ) return

        const bounds = element.getBoundingClientRect()

        progress.value = Math.max(
            0,
            Math.min(
                1,
                (event.clientX - bounds.left - bounds.width * 0.06) /
                    (bounds.width * 0.88),
            ),
        )
    }

    function down(event: PointerEvent) {
        if (
            !enabled() ||
            event.button !== 0 ||
            pointerId !== null
        ) return

        const target = event.currentTarget as HTMLElement
        const bounds = target.getBoundingClientRect()

        // Start from the handle at the left end.
        if (event.clientX > bounds.left + bounds.width * 0.2) return

        event.preventDefault()

        pointerId = event.pointerId
        element = target

        target.setPointerCapture(event.pointerId)
        move(event)
    }

    function finish() {
        if (!enabled()) return

        releasePointer()
        progress.value = 1
        complete()
    }

    function up(event: PointerEvent) {
        if (pointerId !== event.pointerId) return

        move(event)

        const completed = progress.value >= 0.94

        releasePointer()

        if (completed) {
            finish()
        } else {
            progress.value = 0
        }
    }

    onBeforeUnmount(cancel)

    return {
        progress,
        down,
        move,
        up,
        cancel,
        finish,
    }
}