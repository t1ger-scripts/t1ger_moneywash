import { onBeforeUnmount, watch } from 'vue'
import { useUiStore } from '@/shared/stores/ui.store'
import { useRaidStore } from '../stores/raid.store'

export function useRaidFinish() {
    const ui = useUiStore()
    const store = useRaidStore()

    let finishTimer: ReturnType<typeof setTimeout> | undefined
    let sound: AudioContext | undefined

    function playConfirmation() {
        try {
            sound ??= new AudioContext()

            void sound.resume().catch(() => {})

            const oscillator = sound.createOscillator()
            const gain = sound.createGain()

            oscillator.connect(gain)
            gain.connect(sound.destination)

            oscillator.type = 'sine'

            oscillator.frequency.setValueAtTime(
                600,
                sound.currentTime,
            )

            oscillator.frequency.exponentialRampToValueAtTime(
                850,
                sound.currentTime + 0.12,
            )

            gain.gain.setValueAtTime(
                0.025,
                sound.currentTime,
            )

            gain.gain.exponentialRampToValueAtTime(
                0.001,
                sound.currentTime + 0.18,
            )

            oscillator.start()
            oscillator.stop(sound.currentTime + 0.2)
        } catch {
            // Audio must never prevent completion.
        }
    }

    watch(
        () => store.sealed,
        sealed => {
            clearTimeout(finishTimer)

            if (!sealed) return

            playConfirmation()

            finishTimer = setTimeout(() => {
                if (store.sealed) {
                    ui.close('raid')
                }
            }, 800)
        },
        { flush: 'sync' },
    )

    onBeforeUnmount(() => {
        clearTimeout(finishTimer)

        if (sound && sound.state !== 'closed') {
            void sound.close().catch(() => {})
        }
    })
}