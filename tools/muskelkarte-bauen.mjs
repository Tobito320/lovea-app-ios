// Baut die Muskelkarte der App: liest tools/opengym/body-paths.js (Herkunft: tools/opengym/NOTICE.md)
// und schreibt Lovea/Sources/Health/Koerper/muskelkarte.json.
// Jeder Pfad wird zu absoluten M/L/C/Z-Befehlen mit ausgeschriebenem Buchstaben je Segment normalisiert
// (Bögen, q/t, s, h/v, relative Befehle aufgelöst), damit der Swift-Leser nur am Leerzeichen trennen muss.
// Aufruf: node tools/muskelkarte-bauen.mjs [ein.js] [aus.json]
import { readFileSync, writeFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const NUM = /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/y

// Kopf bis Fuß wie MUSCLES in openGym; Reihenfolge = Zeichen- und Treffer-Reihenfolge in der App.
export const MUSKELN = [
  'trapezius', 'deltoids', 'chest', 'upper-back', 'serratus', 'biceps', 'triceps', 'forearm',
  'abs', 'obliques', 'lower-back', 'gluteal', 'quadriceps', 'hamstring', 'adductors', 'hip-flexors',
  'calves', 'tibialis',
]
// Kein Training dran: nur Silhouette, nie gefärbt.
export const STILL = ['head', 'hair', 'neck', 'hands', 'feet', 'knees', 'ankles']

const ZAHLEN = { M: 2, m: 2, L: 2, l: 2, H: 1, h: 1, V: 1, v: 1, C: 6, c: 6, S: 4, s: 4, Q: 4, q: 4, T: 2, t: 2, A: 7, a: 7 }

/** Ein SVG-Pfad (d) zu absoluten Segmenten [{c: 'M'|'L'|'C'|'Z', v: [...]}], volle Genauigkeit. */
export function parse(d) {
  let i = 0
  const n = d.length
  const leer = () => { while (i < n && ' ,\t\r\n'.includes(d[i])) i++ }
  const zahl = () => {
    leer()
    NUM.lastIndex = i
    const m = NUM.exec(d)
    if (!m) throw new Error(`Zahl erwartet bei ${i}: ${d.slice(i, i + 20)}`)
    i += m[0].length
    return parseFloat(m[0])
  }
  // Bogen-Flags sind genau ein Zeichen, auch ohne Trenner ("01-.19").
  const flag = () => {
    leer()
    const c = d[i]
    if (c !== '0' && c !== '1') throw new Error(`Flag erwartet bei ${i}: ${d.slice(i, i + 20)}`)
    i++
    return c === '1'
  }
  const nochZahl = () => { leer(); return i < n && /[-+.\d]/.test(d[i]) }

  const aus = []
  let x = 0, y = 0, sx = 0, sy = 0
  let k2 = null, q1 = null // letzter 2. Kubik-Kontrollpunkt, letzter Quad-Kontrollpunkt (für s und t)
  let cmd = null
  const kubik = (a, b, c2, e, f, g) => { aus.push({ c: 'C', v: [a, b, c2, e, f, g] }); k2 = [c2, e]; q1 = null; x = f; y = g }

  leer()
  while (i < n) {
    if (/[a-zA-Z]/.test(d[i])) { cmd = d[i++] } else if (cmd === null || cmd === 'z' || cmd === 'Z') {
      throw new Error(`Befehl erwartet bei ${i}: ${d.slice(i, i + 20)}`)
    }
    if (cmd === 'z' || cmd === 'Z') {
      aus.push({ c: 'Z', v: [] }); x = sx; y = sy; k2 = null; q1 = null
      leer()
      continue
    }
    if (!(cmd in ZAHLEN)) throw new Error(`Unbekannter Befehl ${cmd}`)
    const rel = cmd === cmd.toLowerCase()
    let erster = true
    // Ein Befehl darf mehrere Parametersätze tragen; nach M/m sind weitere Paare ein L/l.
    while (erster || nochZahl()) {
      erster = false
      const ox = rel ? x : 0, oy = rel ? y : 0 // je Satz neu: relativ zum Ende des vorigen Satzes
      switch (cmd.toUpperCase()) {
        case 'M': {
          const nx = zahl() + (aus.length ? (rel ? x : 0) : 0), ny = zahl() + (aus.length ? (rel ? y : 0) : 0)
          x = nx; y = ny; sx = x; sy = y
          aus.push({ c: 'M', v: [x, y] }); k2 = null; q1 = null
          cmd = rel ? 'l' : 'L'
          break
        }
        case 'L': { const nx = zahl() + (rel ? x : 0), ny = zahl() + (rel ? y : 0); x = nx; y = ny; aus.push({ c: 'L', v: [x, y] }); k2 = null; q1 = null; break }
        case 'H': { x = zahl() + (rel ? x : 0); aus.push({ c: 'L', v: [x, y] }); k2 = null; q1 = null; break }
        case 'V': { y = zahl() + (rel ? y : 0); aus.push({ c: 'L', v: [x, y] }); k2 = null; q1 = null; break }
        case 'C': {
          const a = zahl() + ox, b = zahl() + oy, c2 = zahl() + ox, e = zahl() + oy, f = zahl() + ox, g = zahl() + oy
          kubik(a, b, c2, e, f, g)
          break
        }
        case 'S': {
          const a = k2 ? 2 * x - k2[0] : x, b = k2 ? 2 * y - k2[1] : y
          const c2 = zahl() + ox, e = zahl() + oy, f = zahl() + ox, g = zahl() + oy
          kubik(a, b, c2, e, f, g)
          break
        }
        case 'Q': case 'T': {
          let qx, qy
          if (cmd.toUpperCase() === 'Q') { qx = zahl() + ox; qy = zahl() + oy } else { qx = q1 ? 2 * x - q1[0] : x; qy = q1 ? 2 * y - q1[1] : y }
          const ex = zahl() + ox, ey = zahl() + oy
          const x0 = x, y0 = y
          kubik(x0 + 2 / 3 * (qx - x0), y0 + 2 / 3 * (qy - y0), ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey), ex, ey)
          q1 = [qx, qy]
          break
        }
        case 'A': {
          const rx = zahl(), ry = zahl(), rot = zahl(), fa = flag(), fs = flag()
          const ex = zahl() + ox, ey = zahl() + oy
          for (const s of bogen(x, y, rx, ry, rot, fa, fs, ex, ey)) {
            aus.push(s)
            if (s.c === 'C') k2 = [s.v[2], s.v[3]]
          }
          if (aus.at(-1).c !== 'C') k2 = null
          q1 = null; x = ex; y = ey
          break
        }
      }
    }
  }
  return aus
}

/** Elliptischer Bogen (SVG-Endpunktform, Anhang F.6) als Kubiken, je höchstens 90 Grad. */
export function bogen(x1, y1, rx, ry, rotGrad, fa, fs, x2, y2) {
  if (x1 === x2 && y1 === y2) return []
  rx = Math.abs(rx); ry = Math.abs(ry)
  if (rx === 0 || ry === 0) return [{ c: 'L', v: [x2, y2] }]
  const phi = rotGrad * Math.PI / 180, cp = Math.cos(phi), sp = Math.sin(phi)
  const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2
  const xs = cp * dx + sp * dy, ys = -sp * dx + cp * dy
  const lam = xs * xs / (rx * rx) + ys * ys / (ry * ry)
  if (lam > 1) { const w = Math.sqrt(lam); rx *= w; ry *= w }
  const zaehler = rx * rx * ry * ry - rx * rx * ys * ys - ry * ry * xs * xs
  const nenner = rx * rx * ys * ys + ry * ry * xs * xs
  let f = Math.sqrt(Math.max(0, zaehler / nenner))
  if (fa === fs) f = -f
  const cxs = f * rx * ys / ry, cys = -f * ry * xs / rx
  const cx = cp * cxs - sp * cys + (x1 + x2) / 2, cy = sp * cxs + cp * cys + (y1 + y2) / 2
  const th1 = Math.atan2((ys - cys) / ry, (xs - cxs) / rx)
  const ux = (xs - cxs) / rx, uy = (ys - cys) / ry, vx = (-xs - cxs) / rx, vy = (-ys - cys) / ry
  let dth = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
  if (!fs && dth > 0) dth -= 2 * Math.PI
  else if (fs && dth < 0) dth += 2 * Math.PI
  const anzahl = Math.max(1, Math.ceil(Math.abs(dth) / (Math.PI / 2) - 1e-9))
  const schritt = dth / anzahl
  const t = 4 / 3 * Math.tan(schritt / 4)
  const punkt = (w) => [cx + rx * Math.cos(w) * cp - ry * Math.sin(w) * sp, cy + rx * Math.cos(w) * sp + ry * Math.sin(w) * cp]
  const ableitung = (w) => [-rx * Math.sin(w) * cp - ry * Math.cos(w) * sp, -rx * Math.sin(w) * sp + ry * Math.cos(w) * cp]
  const aus = []
  for (let k = 0; k < anzahl; k++) {
    const a1 = th1 + k * schritt, a2 = a1 + schritt
    const p1 = punkt(a1), p2 = k === anzahl - 1 ? [x2, y2] : punkt(a2)
    const d1 = ableitung(a1), d2 = ableitung(a2)
    aus.push({ c: 'C', v: [p1[0] + t * d1[0], p1[1] + t * d1[1], p2[0] - t * d2[0], p2[1] - t * d2[1], p2[0], p2[1]] })
  }
  return aus
}

const rund = (v) => {
  const s = (Math.round(v * 10) / 10).toString()
  return s === '-0' ? '0' : s
}

/** Normalisierter Pfad als Text: "M x y L x y C x1 y1 x2 y2 x y Z", jeder Befehl mit Buchstabe. */
export function normalisiere(d) {
  return parse(d).map(s => s.v.length ? `${s.c} ${s.v.map(rund).join(' ')}` : s.c).join(' ')
}

/** Baut die JSON-Struktur aus dem Inhalt von body-paths.js. */
export function bauen(quelle) {
  const start = quelle.indexOf('export default')
  if (start < 0) throw new Error('export default fehlt')
  const roh = JSON.parse(quelle.slice(start + 'export default'.length).trim().replace(/;\s*$/, ''))
  const aus = {}
  for (const koerper of ['male', 'female']) {
    aus[koerper] = {}
    for (const seite of ['front', 'back']) {
      const ansicht = roh[koerper][seite]
      const vb = ansicht.vb.split(/\s+/).map(Number)
      if (vb.length !== 4 || vb.some(Number.isNaN)) throw new Error(`viewBox ${koerper}/${seite}`)
      const liste = (slugs) => slugs
        .filter(s => ansicht.p[s])
        .map(s => ({ slug: s, d: ansicht.p[s].map(normalisiere) }))
      const bekannt = new Set([...MUSKELN, ...STILL])
      for (const s of Object.keys(ansicht.p)) if (!bekannt.has(s)) throw new Error(`Unbekannter Slug ${s}`)
      aus[koerper][seite] = { vb, still: liste(STILL), muskeln: liste(MUSKELN) }
    }
  }
  return aus
}

/** Prüft den Normalisierer an kleinen Fällen, bevor etwas geschrieben wird. */
export function selbstpruefung() {
  const gleich = (d, soll) => {
    const ist = normalisiere(d)
    if (ist !== soll) throw new Error(`Selbstprüfung: ${d}\n  ist:  ${ist}\n  soll: ${soll}`)
  }
  gleich('M10 10h5v5z', 'M 10 10 L 15 10 L 15 15 Z')
  gleich('m1 1 2 0 0 2z', 'M 1 1 L 3 1 L 3 3 Z') // erstes m ist absolut, weitere Paare sind l
  gleich('M0 0q10 0 10 10', 'M 0 0 C 6.7 0 10 3.3 10 10')
  gleich('M0 0c1 1 2 2 3 3 1 1 2 2 3 3', 'M 0 0 C 1 1 2 2 3 3 C 4 4 5 5 6 6') // wiederholte Parametersätze
  gleich('M5 5z m1 1l1 0', 'M 5 5 Z M 6 6 L 7 6') // nach z startet der nächste Teilpfad am Anfang des letzten
  gleich('M1.5.5L-.5-.5', 'M 1.5 0.5 L -0.5 -0.5') // Zahlen ohne Trenner
  // Halbkreis mit gepackten Flags: (0,0) nach (2,0), Radius 1, Bogen über oben (sweep 1 = im Uhrzeigersinn, y nach unten).
  const halb = parse('M0 0a1 1 0 01 2 0')
  const ende = halb.at(-1).v
  if (Math.abs(ende[4] - 2) > 1e-9 || Math.abs(ende[5]) > 1e-9 || halb.length !== 3) throw new Error('Selbstprüfung: Halbkreis')
  const mitte = halb[1].v
  if (Math.abs(mitte[4] - 1) > 1e-6 || Math.abs(mitte[5] + 1) > 1e-6) throw new Error('Selbstprüfung: Bogen geht nicht über oben')
  const gepackt = parse('M0 0a1 1 0 012 0')
  if (Math.abs(gepackt.at(-1).v[4] - 2) > 1e-9) throw new Error('Selbstprüfung: gepackte Flags')
}

function hauptprogramm() {
  selbstpruefung()
  const ein = process.argv[2] ?? 'tools/opengym/body-paths.js'
  const aus = process.argv[3] ?? 'Lovea/Sources/Health/Koerper/muskelkarte.json'
  const karte = bauen(readFileSync(ein, 'utf8'))
  for (const k of Object.values(karte)) {
    for (const a of Object.values(k)) {
      for (const t of [...a.still, ...a.muskeln]) {
        for (const d of t.d) {
          if (!/^M [-\d. CLZM]+Z$/.test(d) && !/^M [-\d. CLZM]+$/.test(d)) throw new Error(`Seltsamer Pfad in ${t.slug}`)
        }
      }
    }
  }
  const text = JSON.stringify(karte)
  writeFileSync(aus, text + '\n')
  console.log(`${aus}: ${(text.length / 1024).toFixed(0)} KB`)
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) hauptprogramm()
