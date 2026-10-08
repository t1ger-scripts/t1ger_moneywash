export function createCashTextures(): Record<string, string> {
    const result: Record<string, string> = {}
    const root = {
        style: {
            setProperty: (key: string, value: string) => {
                result[key] = value
            },
        },
    }
    let seed = 811
    function random() {
        seed = (seed * 1664525 + 1013904223) >>> 0
        return seed / 4294967296
    }
    function texture(
        w: number,
        h: number,
        draw: (x: CanvasRenderingContext2D, w: number, h: number) => void,
    ) {
        const c = document.createElement('canvas')
        c.width = w
        c.height = h
        const x = c.getContext('2d')!
        draw(x, w, h)
        return 'url("' + c.toDataURL() + '")'
    }
    root.style.setProperty(
        '--wood',
        texture(700, 360, (x, w, h) => {
            x.fillStyle = '#3c3326'
            x.fillRect(0, 0, w, h)
            for (let i = 0; i < 5000; i++) {
                const y = random() * h
                x.strokeStyle =
                    'rgba(' +
                    (random() > 0.5 ? '149,117,69' : '8,12,7') +
                    ',' +
                    random() * 0.12 +
                    ')'
                x.lineWidth = random() * 2
                x.beginPath()
                x.moveTo(0, y)
                x.bezierCurveTo(
                    170,
                    y + random() * 8,
                    450,
                    y - random() * 8,
                    700,
                    y + random() * 3,
                )
                x.stroke()
            }
            for (let i = 0; i < 110; i++) {
                x.strokeStyle = 'rgba(221,194,140,' + random() * 0.17 + ')'
                const a = random() * w,
                    b = random() * h
                x.beginPath()
                x.moveTo(a, b)
                x.lineTo(a + random() * 70, b + random() * 9)
                x.stroke()
            }
            x.strokeStyle = '#10130a88'
            x.lineWidth = 2
            x.beginPath()
            x.moveTo(0, 170)
            x.lineTo(700, 169)
            x.stroke()
        }),
    )
    root.style.setProperty(
        '--grain',
        texture(100, 100, (x, w, h) => {
            x.clearRect(0, 0, w, h)
            for (let i = 0; i < 4500; i++) {
                x.fillStyle =
                    random() > 0.5 ? 'rgba(210,213,184,.06)' : 'rgba(0,0,0,.10)'
                x.fillRect(random() * w, random() * h, 1, 1)
            }
        }),
    )
    root.style.setProperty(
        '--banknote',
        texture(440, 200, (x, w, h) => {
            x.fillStyle = '#b5bba0'
            x.fillRect(0, 0, w, h)
            x.strokeStyle = '#52634b'
            for (let i = 0; i < 7; i++) {
                x.lineWidth = i % 2 ? 0.6 : 1.5
                x.strokeRect(
                    7 + i * 2,
                    7 + i * 2,
                    w - 14 - i * 4,
                    h - 14 - i * 4,
                )
            }
            for (let i = 0; i < 90; i++) {
                x.strokeStyle = '#66785b44'
                x.beginPath()
                for (let a = 0; a < 440; a += 3) {
                    const y = 17 + i * 1.85 + Math.sin(a * 0.12 + i * 0.6) * 3
                    a ? x.lineTo(a, y) : x.moveTo(a, y)
                }
                x.stroke()
            }
            x.save()
            x.translate(195, 99)
            for (let i = 0; i < 14; i++) {
                x.beginPath()
                x.ellipse(0, 0, 43 + i * 0.8, 65 + i * 0.4, 0, 0, Math.PI * 2)
                x.strokeStyle = '#4f624b'
                x.lineWidth = 0.55
                x.stroke()
            }
            x.fillStyle = '#75826a'
            x.beginPath()
            x.ellipse(0, -13, 24, 33, 0, 0, 7)
            x.fill()
            x.beginPath()
            x.moveTo(-35, 54)
            x.quadraticCurveTo(-38, 15, -13, 14)
            x.lineTo(12, 14)
            x.quadraticCurveTo(42, 25, 36, 55)
            x.fill()
            for (let i = 0; i < 45; i++) {
                x.strokeStyle = '#394d3944'
                x.beginPath()
                x.moveTo(-25 + i, 8)
                x.lineTo(-33 + i, 48)
                x.stroke()
            }
            x.restore()
            x.fillStyle = '#354e34'
            x.textAlign = 'center'
            x.font = 'bold 11px Georgia'
            x.fillText('LOS SANTOS RESERVE NOTE', 220, 31)
            x.font = 'bold 13px Georgia'
            x.fillText('ONE HUNDRED DOLLARS', 220, 181)
            x.font = 'bold 34px Georgia'
            x.fillText('100', 53, 62)
            x.fillText('100', 388, 164)
            x.font = '13px monospace'
            x.fillText('LS 01984276 A', 94, 143)
            x.font = '8px Georgia'
            x.fillText('SAN ANDREAS', 334, 78)
            x.beginPath()
            x.arc(340, 112, 20, 0, 7)
            x.strokeStyle = '#476449'
            x.lineWidth = 3
            x.stroke()
            x.font = 'bold 20px Georgia'
            x.fillText('$', 340, 119)
            for (let i = 0; i < 8500; i++) {
                x.fillStyle = random() > 0.5 ? '#eef2ca15' : '#182a1715'
                x.fillRect(random() * w, random() * h, 1, 1)
            }
        }),
    )
    return result
}
