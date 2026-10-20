import { onBeforeUnmount, watch } from 'vue'
import { useRaidStore } from '../stores/raid.store'

/**
 * Plays the confirmation sound when the server accepts the seal.
 * Closing the screen is handled by the store, which also tells Lua.
 */
export function useRaidFinish() {
    const store = useRaidStore()

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
            if (sealed) playConfirmation()
        },
        { flush: 'sync' },
    )

    onBeforeUnmount(() => {
        if (sound && sound.state !== 'closed') {
            void sound.close().catch(() => {})
        }
    })
}