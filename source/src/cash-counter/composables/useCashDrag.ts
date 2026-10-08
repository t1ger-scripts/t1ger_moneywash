import { ref, type Ref } from 'vue'
export function useCashDrag(
    root: Ref<HTMLElement | null>,
    enabled: () => boolean,
    submit: () => void,
) {
    const dragging = ref(false),
        over = ref(false),
        x = ref(0),
        y = ref(0)
    let pointer: number | null = null
    function cancel() {
        dragging.value = false
        over.value = false
        pointer = null
    }
    function move(event: PointerEvent) {
        if (pointer !== event.pointerId || !root.value) return
        const origin = root.value.getBoundingClientRect()
        x.value = event.clientX - origin.left
        y.value = event.clientY - origin.top
        const target = root.value
            .querySelector('[data-cash-feeder]')
            ?.getBoundingClientRect()
        over.value =
            !!target &&
            event.clientX >= target.left &&
            event.clientX <= target.right &&
            event.clientY >= target.top &&
            event.clientY <= target.bottom
    }
    function down(event: PointerEvent) {
        if (!enabled() || event.button !== 0) return
        event.preventDefault()
        pointer = event.pointerId
        dragging.value = true
        ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
        move(event)
    }
    function up(event: PointerEvent) {
        if (pointer !== event.pointerId) return
        const accepted = over.value
        cancel()
        if (accepted && enabled()) submit()
    }
    return { dragging, over, x, y, down, move, up, cancel }
}
