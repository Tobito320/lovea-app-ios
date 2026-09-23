// Generates the heartbeat notification sound: 16-bit PCM mono WAV, 1.2 s, two lub-dub beats.
// Usage: node tools/herzschlag.mjs [out.wav]
import { writeFileSync } from 'node:fs'

const out = process.argv[2] ?? 'Lovea/Sources/Figuren/herzschlag.wav'
const rate = 22050
const n = Math.round(rate * 1.2)
const s = new Float64Array(n)

function thump(start, gain) {
  const i0 = Math.round(start * rate)
  for (let i = i0; i < n; i++) {
    const t = (i - i0) / rate
    if (t > 0.35) break
    // ~55 Hz with a small pitch drop; harmonics so phone speakers can play it.
    const phase = 2 * Math.PI * (55 * t + (25 * (1 - Math.exp(-t * 30))) / 30)
    const env = Math.min(1, t / 0.004) * Math.exp(-t * 16)
    s[i] += gain * env * (Math.sin(phase) + 0.5 * Math.sin(2 * phase) + 0.25 * Math.sin(3 * phase))
  }
}

for (const beat of [0, 0.6]) {
  thump(beat + 0.02, 1)
  thump(beat + 0.24, 0.7)
}

const peak = s.reduce((m, v) => Math.max(m, Math.abs(v)), 0) || 1
const buf = Buffer.alloc(44 + n * 2)
buf.write('RIFF', 0)
buf.writeUInt32LE(36 + n * 2, 4)
buf.write('WAVE', 8)
buf.write('fmt ', 12)
buf.writeUInt32LE(16, 16)
buf.writeUInt16LE(1, 20)
buf.writeUInt16LE(1, 22)
buf.writeUInt32LE(rate, 24)
buf.writeUInt32LE(rate * 2, 28)
buf.writeUInt16LE(2, 32)
buf.writeUInt16LE(16, 34)
buf.write('data', 36)
buf.writeUInt32LE(n * 2, 40)
for (let i = 0; i < n; i++) buf.writeInt16LE(Math.round((s[i] / peak) * 0.9 * 32767), 44 + i * 2)
writeFileSync(out, buf)
console.log(`${out}: ${buf.length} bytes, ${(n / rate).toFixed(2)} s`)
