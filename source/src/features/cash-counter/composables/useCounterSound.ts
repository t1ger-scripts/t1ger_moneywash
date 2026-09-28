// A quiet motor and short filtered noise bursts simulate bills passing the rollers.
// Sounds are generated locally; the counting speed is independent of the amount.
export function useCounterSound() {
    let context: AudioContext | null = null
    let noise: AudioBuffer | null = null
    let motor: AudioBufferSourceNode | null = null
    let hum: OscillatorNode | null = null
    let lastFeed = 0

    function prime() {
        try {
            context ??= new AudioContext()
            if (context.state === 'suspended') void context.resume()
        } catch { /* Audio is optional when CEF has no audio device. */ }
    }

    function noiseBuffer() {
        if (!context) return null
        if (!noise) {
            noise = context.createBuffer(1, context.sampleRate, context.sampleRate)
            const samples = noise.getChannelData(0)
            for (let i = 0; i < samples.length; i++) {
                samples[i] = Math.random() * 2 - 1
            }
        }
        return noise
    }

    function paper(volume = 0.025, duration = 0.045, frequency = 1400) {
        if (!context || context.state !== 'running') return
        const buffer = noiseBuffer()
        if (!buffer) return

        const source = context.createBufferSource()
        source.buffer = buffer

        const filter = context.createBiquadFilter()
        filter.type = 'bandpass'
        filter.frequency.value = frequency
        filter.Q.value = 0.65

        const gain = context.createGain()
        const at = context.currentTime
        gain.gain.setValueAtTime(0.0001, at)
        gain.gain.linearRampToValueAtTime(volume, at + 0.004)
        gain.gain.exponentialRampToValueAtTime(0.0001, at + duration)

        source.connect(filter).connect(gain).connect(context.destination)
        source.onended = () => {
            source.disconnect()
            filter.disconnect()
            gain.disconnect()
        }
        source.start(at, Math.random() * (buffer.duration - duration))
        source.stop(at + duration)
    }

    function start() {
        prime()
        if (!context || motor || context.state !== 'running') return
        const buffer = noiseBuffer()
        if (!buffer) return

        motor = context.createBufferSource()
        motor.buffer = buffer
        motor.loop = true

        const motorFilter = context.createBiquadFilter()
        motorFilter.type = 'lowpass'
        motorFilter.frequency.value = 370

        const motorGain = context.createGain()
        motorGain.gain.value = 0.012
        motor.connect(motorFilter).connect(motorGain).connect(context.destination)
        motor.onended = () => {
            motorFilter.disconnect()
            motorGain.disconnect()
        }
        motor.start()

        hum = context.createOscillator()
        hum.type = 'sine'
        hum.frequency.value = 78

        const humGain = context.createGain()
        humGain.gain.value = 0.004
        hum.connect(humGain).connect(context.destination)
        hum.onended = () => { humGain.disconnect() }
        hum.start()

        lastFeed = 0
        paper(0.032, 0.065, 800)
    }

    function feed() {
        if (!motor || performance.now() - lastFeed < 95) return
        lastFeed = performance.now()
        paper(0.018 + Math.random() * 0.009, 0.035, 1050 + Math.random() * 500)
    }

    function stop() {
        if (motor) { motor.stop(); motor = null }
        if (hum) { hum.stop(); hum = null }
    }

    function counted() {
        stop()
        paper(0.045, 0.085, 700)
    }

    function deposited() {
        paper(0.028, 0.045, 1000)
    }

    function dispose() {
        stop()
        if (context) void context.close()
        context = null
        noise = null
    }

    return { prime, start, feed, stop, counted, deposited, dispose }
}