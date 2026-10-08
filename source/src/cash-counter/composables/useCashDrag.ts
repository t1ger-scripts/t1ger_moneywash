import { ref, type Ref } from 'vue'

export function useCashDrag(
    root: Ref<HTMLElement | null>,
    enabled: () => boolean,
    submit: () => void | Promise<void>,
    targetSelector = '[data-cash-feeder]',
) {
    const dragging = ref(false)
    const animating = ref(false)
    const over = ref(false)
    const x = ref(0)
    const y = ref(0)

    let pointer: number | null = null
    let source: HTMLElement | null = null
    let origin = { x: 0, y: 0 }
    let frame = 0
    let generation = 0
    let finishAnimation: ((completed: boolean) => void) | null = null

    function releasePointer() {
        const previousPointer = pointer
        const previousSource = source

        pointer = null
        source = null

        if (
            previousPointer !== null &&
            previousSource?.hasPointerCapture(previousPointer)
        ) {
            previousSource.releasePointerCapture(previousPointer)
        }
    }

    function cancel() {
        generation++
        cancelAnimationFrame(frame)
        finishAnimation?.(false)
        finishAnimation = null
        releasePointer()

        dragging.value = false
        animating.value = false
        over.value = false
    }

    function centerOf(element: Element) {
        if (!root.value) return null

        const bounds = element.getBoundingClientRect()
        const container = root.value.getBoundingClientRect()

        return {
            x: bounds.left + bounds.width / 2 -
                container.left + root.value.scrollLeft,
            y: bounds.top + bounds.height / 2 -
                container.top + root.value.scrollTop,
        }
    }

    function destination() {
        const target = root.value?.querySelector(targetSelector)
        if (!target) return null

        return centerOf(
            target.querySelector('[data-cash-landing]') ?? target,
        )
    }

    function animateTo(point: { x: number; y: number }) {
        animating.value = true

        const from = { x: x.value, y: y.value }
        const started = performance.now()
        const duration = window.matchMedia(
            '(prefers-reduced-motion: reduce)',
        ).matches ? 0 : 180

        return new Promise<boolean>((resolve) => {
            finishAnimation = resolve

            function tick(now: number) {
                const progress = duration === 0
                    ? 1
                    : Math.min(1, (now - started) / duration)

                const eased = 1 - (1 - progress) ** 3

                x.value = from.x + (point.x - from.x) * eased
                y.value = from.y + (point.y - from.y) * eased

                if (progress < 1) {
                    frame = requestAnimationFrame(tick)
                    return
                }

                finishAnimation = null
                resolve(true)
            }

            frame = requestAnimationFrame(tick)
        })
    }

    async function settle(accepted: boolean) {
        const version = generation
        const target = accepted ? destination() : null

        try {
            const finished = await animateTo(target ?? origin)

            if (
                !finished ||
                version !== generation ||
                !accepted ||
                !target ||
                !enabled()
            ) return

            await submit()
        } finally {
            if (version === generation) cancel()
        }
    }

    function move(event: PointerEvent) {
        if (
            pointer !== event.pointerId ||
            animating.value ||
            !root.value
        ) return

        const container = root.value.getBoundingClientRect()

        x.value = event.clientX - container.left + root.value.scrollLeft
        y.value = event.clientY - container.top + root.value.scrollTop

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
            dragging.value
        ) return

        const element = event.target instanceof Element
            ? event.target.closest('.cash-bundle')
            : null

        if (!element) return

        const point = centerOf(element)
        if (!point) return

        event.preventDefault()
        generation++

        origin = point
        pointer = event.pointerId
        source = event.currentTarget as HTMLElement
        source.setPointerCapture(event.pointerId)

        dragging.value = true
        move(event)
    }

    function up(event: PointerEvent) {
        if (pointer !== event.pointerId || animating.value) return

        move(event)
        const accepted = over.value && enabled()
        releasePointer()

        void settle(accepted)
    }

    async function transfer(element: HTMLElement) {
        if (!enabled() || dragging.value) return

        const pile = element.matches('.cash-bundle')
            ? element
            : element.querySelector('.cash-bundle:last-child')

        if (!pile) return

        const point = centerOf(pile)
        if (!point) return

        generation++
        origin = point
        x.value = point.x
        y.value = point.y
        dragging.value = true
        over.value = true

        await settle(true)
    }

    return {
        dragging,
        animating,
        over,
        x,
        y,
        down,
        move,
        up,
        cancel,
        transfer,
    }
}