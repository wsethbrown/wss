import { Controller } from "@hotwired/stimulus"

// Concept 4: "The Theatre of the Pour" (/concepts/4)
// KEY PRINCIPLE (owner feedback):
//   Scroll ONLY selects the active beat (0..4) with hysteresis.
//   Every transition then plays to FULL, CRISP COMPLETION on its own clock!
//   Nothing EVER freezes halfway mid-animation!
//
// Highlights:
// - Circular iris wipe into Beat 2 (Orange Invite); theatre curtain dim into Beat 3.
// - Masked kinetic line-reveal headlines.
// - Clickable sibling decks in Beat 1 swap into the Hero Deck & carry into Beats 2 & 3!
// - Beat 3 auto-runs a sequential 4-pour stream choreography (Pour 1 -> 2 -> 3 -> 4),
//   filling each glass from 0 to its real height with individual splash slosh!
// - Beat 4 launches all 4 glasses on PARABOLIC CURVED ARCS with stagger, physically
//   sorting them mid-air from serve order into winner order (#1 top -> #4 bottom),
//   followed by staggered blooming Palate Wheel wedges!

const POURS = [
  { name: "Buffalo Trace",          proof: "90°",    score: "4.10", level: 0.72, rank: 3, wheel: [0.85, 0.52, 0.36, 0.72, 0.14, 0.50, 0.44, 0.10] },
  { name: "Maker's Mark 46",        proof: "94°",    score: "4.25", level: 0.78, rank: 2, wheel: [0.92, 0.80, 0.48, 0.62, 0.20, 0.42, 0.35, 0.10] },
  { name: "Heaven Hill 7yr BiB",    proof: "100°",   score: "4.40", level: 0.85, rank: 1, wheel: [0.76, 0.85, 0.72, 0.45, 0.24, 0.65, 0.25, 0.12] },
  { name: "Wild Turkey Rare Breed", proof: "116.8°", score: "4.65", level: 0.94, rank: 0, wheel: [0.72, 0.96, 0.92, 0.58, 0.42, 0.55, 0.20, 0.18] }
]

const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v))
const lerp = (a, b, t) => a + (b - a) * t
const easeOutCubic = (t) => 1 - Math.pow(1 - clamp(t), 3)
const easeOutBack = (t) => {
  const c = clamp(t)
  const c1 = 1.45, c3 = c1 + 1
  return 1 + c3 * Math.pow(c - 1, 3) + c1 * Math.pow(c - 1, 2)
}

export default class extends Controller {
  static targets = [
    "theatre", "stage", "sentinel", "copy", "dockBtn",
    "deckShell", "deckSheen", "dslide", "deckCapL", "deckCapR", "deckTitle",
    "rsvpChip",
    "pourSvg", "glass", "gcap", "rank",
    "wheelTitle", "wheelScore", "wedge",
    "restGlass"
  ]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.beat = 0
    this.chosenDeck = "Bourbon Basics"
    this.rsvpIn = false
    this.slideIdx = 0
    this.activeWheelIdx = 3
    this.mx = 0; this.my = 0; this.curMx = 0; this.curMy = 0
    this.running = true
    this.seqTimers = []

    // Per-glass independent physics state (position, scale, opacity, level, slosh, arc flight!)
    this.gState = POURS.map((_, k) => {
      const p = this.poseFor(0, k)
      return {
        x: p.x, y: p.y, sc: p.sc, op: p.op, lvl: p.lvl, rot: 0,
        from: { ...p }, to: { ...p }, ctrl: { x: p.x, y: p.y },
        tStart: 0, dur: 0.001, active: false,
        slosh: 0, sloshVel: 0,
        targetLvl: p.lvl
      }
    })
    this.restSlosh = 0
    this.restSloshVel = 0

    this.onScroll = this.onScroll.bind(this)
    this.onMouseMove = this.onMouseMove.bind(this)
    this.onKeyDown = this.onKeyDown.bind(this)
    this.loop = this.loop.bind(this)

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    window.addEventListener("mousemove", this.onMouseMove, { passive: true })
    window.addEventListener("keydown", this.onKeyDown)

    this.enterBeat(0, true)
    this.onScroll()
    this.raf = requestAnimationFrame(this.loop)
  }

  disconnect() {
    this.running = false
    this.clearTimers()
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    window.removeEventListener("mousemove", this.onMouseMove)
    window.removeEventListener("keydown", this.onKeyDown)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  clearTimers() {
    this.seqTimers.forEach((id) => clearTimeout(id))
    this.seqTimers = []
  }

  after(ms, fn) {
    const id = setTimeout(fn, this.reduced ? 0 : ms)
    this.seqTimers.push(id)
  }

  // Target resting pose of glass k for a given beat (0..4)
  poseFor(beat, k) {
    const mobile = window.innerWidth < 900
    const pour = POURS[k]
    if (beat === 0) {
      return { x: -2, y: 34, sc: 0.72, op: k === 0 ? 0.96 : 0, lvl: 0.1 }
    }
    if (beat === 1) {
      return { x: 0, y: 35, sc: 0.78, op: k === 0 ? 1 : 0, lvl: 0.36 }
    }
    if (beat === 2) {
      const invXs = mobile ? [ -28, -10, 8, 26 ] : [ -26, -18, -10, -2 ]
      return { x: invXs[k], y: 31, sc: 0.62, op: 1, lvl: 0.62 }
    }
    if (beat === 3) {
      const tblXs = mobile ? [ -34, -11, 11, 34 ] : [ -24, -8, 8, 24 ]
      return { x: tblXs[k], y: 26, sc: mobile ? 0.68 : 0.98, op: 1, lvl: 0.08 } // fills sequentially!
    }
    // Beat 4: Mid-air sorted vertical podium on the left!
    const sortYs = [ -14, 1, 16, 31 ]
    return {
      x: mobile ? -38 : -36,
      y: sortYs[pour.rank],
      sc: mobile ? 0.54 : 0.66,
      op: 1,
      lvl: pour.level
    }
  }

  // Scroll only picks WHICH beat is active (with hysteresis) and parks the stage at bottom
  onScroll() {
    if (!this.hasTheatreTarget || !this.hasStageTarget) return
    const tRect = this.theatreTarget.getBoundingClientRect()
    const pastEnd = tRect.bottom <= window.innerHeight + 2
    this.stageTarget.classList.toggle("is-parked", pastEnd)

    // Determine active beat from sentinel centers with hysteresis so it never chatters
    const mid = window.innerHeight * 0.52
    let best = this.beat
    const rects = this.sentinelTargets.map((el) => el.getBoundingClientRect())

    // Forward threshold: top crosses 56% of viewport; backward threshold: bottom drops below 44%
    for (let i = 0; i < rects.length; i++) {
      if (rects[i].top <= mid && rects[i].bottom >= mid) {
        best = i
        break
      }
    }
    if (rects[0] && rects[0].top > mid) best = 0
    if (rects[rects.length - 1] && rects[rects.length - 1].bottom < mid) best = rects.length - 1

    if (best !== this.beat) {
      this.enterBeat(best, false)
    }
  }

  onMouseMove(e) {
    if (this.reduced) return
    this.mx = (e.clientX / window.innerWidth - 0.5) * 2
    this.my = (e.clientY / window.innerHeight - 0.5) * 2
  }

  onKeyDown(e) {
    if (this.stageTarget?.classList.contains("is-parked")) return
    if (e.target.closest("input, textarea, button, a")) return
    if (e.key === "ArrowDown" && this.beat < 4) {
      e.preventDefault(); this.scrollToBeat(this.beat + 1)
    } else if (e.key === "ArrowUp" && this.beat > 0) {
      e.preventDefault(); this.scrollToBeat(this.beat - 1)
    }
  }

  jumpBeat(event) {
    const b = parseInt(event.currentTarget.dataset.beat, 10)
    this.scrollToBeat(b)
  }

  scrollToBeat(b) {
    const target = this.sentinelTargets[b]
    if (!target) return
    const y = target.getBoundingClientRect().top + window.scrollY + (b === 0 ? 0 : 8)
    window.scrollTo({ top: y, behavior: this.reduced ? "auto" : "smooth" })
  }

  // Trigger a FULL choreographed clock-driven Beat transition!
  enterBeat(nextBeat, instant = false) {
    const prevBeat = this.beat
    this.beat = nextBeat
    this.clearTimers()

    if (this.hasStageTarget) this.stageTarget.dataset.beat = String(nextBeat)
    this.copyTargets.forEach((el, i) => el.classList.toggle("is-active", i === nextBeat))
    this.dockBtnTargets.forEach((el, i) => el.classList.toggle("is-active", i === nextBeat))

    // Update deck bar caption
    const caps = [
      [ this.chosenDeck, "24 slides · Click to flip" ],
      [ this.chosenDeck, "Click a deck beside it to swap" ],
      [ `Attached: ${this.chosenDeck}`, "Ready for Friday" ],
      [ `Presenting: ${this.chosenDeck}`, "Pouring 1 – 4" ],
      [ "The tasting record", "Ranked by the room" ]
    ]
    if (this.hasDeckCapLTarget) this.deckCapLTarget.textContent = caps[nextBeat][0]
    if (this.hasDeckCapRTarget) this.deckCapRTarget.textContent = caps[nextBeat][1]

    // Reset Beat 3 / Beat 4 overlays
    if (this.hasPourSvgTarget) this.pourSvgTarget.classList.remove("is-pouring")
    this.gcapTargets.forEach((c) => c.classList.toggle("is-visible", nextBeat === 3))
    this.rankTargets.forEach((r) => r.classList.remove("is-visible"))

    const nowSec = performance.now() * 0.001

    // Launch all 4 glasses on PARABOLIC CURVED ARCS to their new beat poses!
    this.gState.forEach((g, k) => {
      const dest = this.poseFor(nextBeat, k)
      g.from = { x: g.x, y: g.y, sc: g.sc, op: g.op, lvl: g.lvl }
      g.to = { ...dest }
      // Parabolic control point: lifts gracefully into an arc during Beat 2 fan-out and Beat 4 mid-air sort!
      const midX = (g.from.x + dest.x) * 0.5
      const arcLift = nextBeat === 4 ? -14 - k * 3.5 : (nextBeat === 2 ? -10 : -6)
      g.ctrl = { x: midX + (nextBeat === 4 ? (k % 2 === 0 ? -6 : 6) : 0), y: Math.min(g.from.y, dest.y) + arcLift }

      const stagger = instant || this.reduced ? 0 : (nextBeat === 4 ? k * 0.085 : k * 0.065)
      g.tStart = nowSec + stagger
      g.dur = instant || this.reduced ? 0.001 : (nextBeat === 4 ? 0.92 : 0.78)
      g.active = true
      g.targetLvl = dest.lvl
      g.landedKick = false
    })

    // --- BEAT 3 PERFORMANCE: Automated Sequential 4-Glass Pour Choreography! ---
    if (nextBeat === 3) {
      const mobile = window.innerWidth < 900
      const tblXs = mobile ? [ -34, -11, 11, 34 ] : [ -24, -8, 8, 24 ]
      POURS.forEach((pour, k) => {
        this.after(520 + k * 460, () => {
          if (this.beat !== 3) return
          if (this.hasPourSvgTarget) {
            this.pourSvgTarget.style.transform = `translate3d(calc(-50% + ${tblXs[k]}vw), 4svh, 0)`
            this.pourSvgTarget.classList.add("is-pouring")
          }
          this.gState[k].targetLvl = pour.level
          this.gState[k].sloshVel += (k % 2 === 0 ? 5.2 : -5.2)
        })
      })
      this.after(520 + 4 * 460 + 260, () => {
        if (this.hasPourSvgTarget) this.pourSvgTarget.classList.remove("is-pouring")
      })
    }

    // --- BEAT 4 PERFORMANCE: Mid-Air Sort Land -> Ranked Cards -> Blooming Palate Wheel! ---
    if (nextBeat === 4) {
      // Collapse wedges first so they bloom outward freshly when Beat 4 arrives!
      if (!this.reduced) {
        this.wedgeTargets.forEach((w) => {
          w.style.transitionDelay = "0ms"
          w.style.transform = "scale(0.08)"
          w.style.opacity = "0"
        })
      }
      this.after(640, () => {
        if (this.beat !== 4) return
        this.rankTargets.forEach((r) => r.classList.add("is-visible"))
      })
      this.after(780, () => {
        if (this.beat !== 4) return
        this.applyWheel(3, true)
      })
    }

    // Kick gentle celebratory slosh on Beat 2 invite arrival
    if (nextBeat === 2 && !instant) {
      this.after(320, () => {
        this.gState.forEach((g, k) => { g.sloshVel += (k - 1.5) * 2.2 })
      })
    }
  }

  // --- Interactive Actions ---
  nextSlide() {
    if (!this.dslideTargets.length) return
    this.slideIdx = (this.slideIdx + 1) % this.dslideTargets.length
    this.dslideTargets.forEach((s, i) => s.classList.toggle("is-active", i === this.slideIdx))
    this.gState[0].sloshVel += 3.2
  }

  swapDeck(event) {
    const title = event.currentTarget.dataset.title
    if (!title) return
    this.chosenDeck = title
    this.deckTitleTargets.forEach((el) => { el.textContent = title })
    if (this.hasDeckCapLTarget) this.deckCapLTarget.textContent = title
    this.gState[0].sloshVel += 4.0
    this.gState[0].targetLvl = Math.min(0.65, this.gState[0].targetLvl + 0.14)
  }

  toggleRsvp() {
    this.rsvpIn = !this.rsvpIn
    if (this.hasRsvpChipTarget) {
      this.rsvpChipTarget.classList.toggle("is-in", this.rsvpIn)
      this.rsvpChipTarget.textContent = this.rsvpIn ? "Seat saved · 6 going ✓" : "Save my seat"
    }
    this.gState.forEach((g, k) => {
      g.sloshVel += (k % 2 === 0 ? 4.4 : -4.4)
      g.targetLvl = this.rsvpIn ? 0.82 : 0.62
    })
  }

  tapGlass(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (this.beat === 3) {
      // Re-pour pulse on clicked glass & flip projected slide!
      this.gState[idx].sloshVel += 6.2
      this.nextSlide()
    } else if (this.beat === 4) {
      this.applyWheel(idx, false)
      this.gState[idx].sloshVel += 5.4
    }
  }

  hoverRank(event) {
    if (this.beat !== 4) return
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (idx !== this.activeWheelIdx) {
      this.applyWheel(idx, false)
      this.gState[idx].sloshVel += 3.6
    }
  }

  applyWheel(idx, staggered = false) {
    this.activeWheelIdx = idx
    const pour = POURS[idx] || POURS[3]
    this.rankTargets.forEach((r) => r.classList.toggle("is-active", parseInt(r.dataset.index, 10) === idx))
    if (this.hasWheelTitleTarget) this.wheelTitleTarget.textContent = pour.name
    if (this.hasWheelScoreTarget) this.wheelScoreTarget.textContent = `${pour.score} / 5`

    this.wedgeTargets.forEach((w, i) => {
      const v = pour.wheel[i] ?? 0.22
      w.style.transitionDelay = staggered && !this.reduced ? `${i * 55}ms` : "0ms"
      w.style.transform = `scale(${(0.24 + v * 0.76).toFixed(3)})`
      w.style.opacity = (0.25 + v * 0.75).toFixed(2)
      w.setAttribute("fill", v >= 0.72 ? "#ff6d00" : (v >= 0.5 ? "#16332a" : "#8fa397"))
    })
  }

  // Render wavy sloshing liquid inside shared/_glass (viewBox 0 0 60 80)
  drawLiquid(svgEl, level, slosh, phase, creamMode) {
    svgEl.classList.toggle("is-cream", creamMode)
    const body = svgEl.querySelector("g > path")
    if (!body) return
    const lvl = clamp(level, 0, 1)
    if (lvl < 0.02) { body.setAttribute("d", ""); return }

    const baseY = 58.5 - lvl * 24
    const tilt = clamp(slosh, -7, 7)
    const wave = Math.sin(phase) * (0.85 + Math.abs(tilt) * 0.22)
    const yL = (baseY - tilt + wave).toFixed(2)
    const yM1 = (baseY - tilt * 0.35 - wave * 1.1).toFixed(2)
    const yM2 = (baseY + tilt * 0.35 + wave * 1.1).toFixed(2)
    const yR = (baseY + tilt - wave).toFixed(2)

    body.setAttribute("d", `M 6 ${yL} C 18 ${yM1}, 38 ${yM2}, 54 ${yR} L 54 70 L 6 70 Z`)
    body.setAttribute("fill", creamMode ? "#ff6d00" : "#e65c00")
  }

  loop(now) {
    if (!this.running) return
    const t = now * 0.001

    if (!this.reduced) {
      this.curMx += (this.mx - this.curMx) * 0.08
      this.curMy += (this.my - this.curMy) * 0.08
    }

    // 3D mouse tilt on Hero / Projection Deck
    if (this.hasDeckShellTarget) {
      const tiltAmt = this.beat === 0 ? 7.5 : (this.beat === 3 ? 3 : 1.5)
      this.deckShellTarget.style.transform = `rotateX(${(-this.curMy * tiltAmt).toFixed(2)}deg) rotateY(${(this.curMx * tiltAmt).toFixed(2)}deg)`
    }
    if (this.hasDeckSheenTarget) {
      this.deckSheenTarget.style.setProperty("--sx", `${(50 + this.curMx * 32).toFixed(1)}%`)
      this.deckSheenTarget.style.setProperty("--sy", `${(35 + this.curMy * 28).toFixed(1)}%`)
    }

    const isDark = this.beat >= 3

    // Advance all 4 glass actors along their parabolic Bézier arcs + independent slosh springs!
    this.gState.forEach((g, k) => {
      if (g.active) {
        const raw = (t - g.tStart) / g.dur
        if (raw >= 0) {
          const u = easeOutCubic(clamp(raw, 0, 1))
          const inv = 1 - u
          // Quadratic Bézier curved flight path!
          g.x = inv * inv * g.from.x + 2 * inv * u * g.ctrl.x + u * u * g.to.x
          g.y = inv * inv * g.from.y + 2 * inv * u * g.ctrl.y + u * u * g.to.y
          g.sc = lerp(g.from.sc, g.to.sc, easeOutBack(clamp(raw, 0, 1)))
          g.op = lerp(g.from.op, g.to.op, clamp(raw * 1.4, 0, 1))
          // Subtle bank angle into the flight direction, settling cleanly to 0 on landing
          const dx = g.to.x - g.from.x
          g.rot = Math.sin(u * Math.PI) * clamp(dx * 0.16, -8, 8)

          if (raw >= 1) {
            g.active = false
            g.x = g.to.x; g.y = g.to.y; g.sc = g.to.sc; g.op = g.to.op; g.rot = 0
            // Kick real landing slosh the instant the glass touches down!
            if (!g.landedKick && !this.reduced) {
              g.landedKick = true
              g.sloshVel += (k % 2 === 0 ? 4.8 : -4.8)
            }
          }
        }
      }

      // Smoothly pour liquid level toward targetLvl
      g.lvl += (g.targetLvl - g.lvl) * (this.reduced ? 1 : 0.09)

      // Independent damped spring slosh physics per glass!
      if (!this.reduced) {
        g.sloshVel += -g.slosh * 0.14
        g.sloshVel *= 0.87
        g.slosh += g.sloshVel * 0.17
      }

      const el = this.glassTargets[k]
      if (el) {
        const px = g.x + (this.beat === 3 ? this.curMx * (1.2 + k * 0.2) : 0)
        const py = g.y + (this.beat === 3 ? this.curMy * 0.7 : 0)
        el.style.opacity = g.op.toFixed(3)
        el.style.pointerEvents = g.op > 0.4 ? "auto" : "none"
        el.style.transform = `translate3d(calc(-50% + ${px.toFixed(2)}vw), calc(-50% + ${py.toFixed(2)}svh), 0) scale(${g.sc.toFixed(3)}) rotate(${g.rot.toFixed(2)}deg)`
        const svg = el.querySelector("svg")
        if (svg) this.drawLiquid(svg, g.lvl, g.slosh + Math.sin(t * 2.1 + k * 1.5) * 0.4, t * 4.3 + k * 1.2, isDark)
      }
    })

    // Gentle living wave on the resting Spotlight glass below
    if (this.hasRestGlassTarget) {
      const rsvg = this.restGlassTarget.querySelector("svg")
      if (rsvg) this.drawLiquid(rsvg, 0.94, Math.sin(t * 1.8) * 0.5, t * 3.1, false)
    }

    this.raf = requestAnimationFrame(this.loop)
  }
}
