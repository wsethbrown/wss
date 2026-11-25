import { Controller } from "@hotwired/stimulus"

// Concept 4: "The Theatre of the Pour" — Tightened v2
// Fixes every laptop-viewport issue from real MacBook Safari review:
// - Pure position: sticky stage (zero fixed->parked jump, zero bottom peek)
// - Laptop-safe non-overlapping coordinates across all 5 beats
// - Paper-backed bowl on Beat 2 orange so pours are 100% crisp & visible
// - Physical 3D deck-swap animation when clicking a flanking deck in Beat 1
//   (swaps actual cover/title/meta between center & flank and carries forward!)
// - Refined Beat 3 living pour: sequential glass rise + illuminated coaster ring
//   + gentle slosh wave (removed the dashed vertical stream)
// - Clean vertical spacing on Beat 4 sorted leaderboard (zero headline overlap)

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
  const c1 = 1.25, c3 = c1 + 1
  return 1 + c3 * Math.pow(c - 1, 3) + c1 * Math.pow(c - 1, 2)
}

export default class extends Controller {
  static targets = [
    "theatre", "stage", "sentinel", "copy", "railBtn",
    "deck", "deckShell", "deckSheen", "dslide", "deckCapL", "deckCapR", "deckTitle", "swapCover",
    "rsvpChip",
    "glass", "gcap", "rank",
    "wheelTitle", "wheelScore", "wedge",
    "restGlass"
  ]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.beat = 0
    this.chosenDeck = this.element.dataset.initialDeck || "Bourbon Basics"
    this.rsvpIn = false
    this.slideIdx = 0
    this.activeWheelIdx = 3
    this.mx = 0; this.my = 0; this.curMx = 0; this.curMy = 0
    this.running = true
    this.seqTimers = []
    this.swapping = false

    this.gState = POURS.map((_, k) => {
      const p = this.poseFor(0, k)
      return {
        x: p.x, y: p.y, sc: p.sc, op: p.op, lvl: p.lvl, rot: 0,
        from: { ...p }, to: { ...p }, ctrl: { x: p.x, y: p.y },
        tStart: 0, dur: 0.001, active: false,
        slosh: 0, sloshVel: 0, targetLvl: p.lvl
      }
    })

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

  // Laptop-safe non-overlapping coordinates (in vw / vh relative to stage center 50%, 50%)
  poseFor(beat, k) {
    const mobile = window.innerWidth < 900
    const pour = POURS[k]
    if (beat === 0) {
      return { x: -2, y: 36, sc: 0.68, op: k === 0 ? 0.96 : 0, lvl: 0.14 }
    }
    if (beat === 1) {
      return { x: 0, y: 39, sc: 0.68, op: k === 0 ? 1 : 0, lvl: 0.42 }
    }
    if (beat === 2) {
      // Positioned cleanly under the right-hand docked deck card — ZERO text overlap!
      const invXs = mobile ? [ -24, -8, 8, 24 ] : [ 12, 20.5, 29, 37.5 ]
      return { x: invXs[k], y: 34, sc: 0.58, op: 1, lvl: 0.72 }
    }
    if (beat === 3) {
      // Comfortably seated on the bottom oak table with full air below captions
      const tblXs = mobile ? [ -34, -11, 11, 34 ] : [ -26, -8.5, 8.5, 26 ]
      return { x: tblXs[k], y: 29, sc: mobile ? 0.64 : 0.88, op: 1, lvl: 0.06 }
    }
    // Beat 4: Sorted vertical podium well below the top-left headline!
    // Center 50% + [-7, 7, 21, 35] -> 43vh, 57vh, 71vh, 85vh (headline ends by ~28vh!)
    const sortYs = [ -7, 7, 21, 35 ]
    return {
      x: mobile ? -38 : -37,
      y: sortYs[pour.rank],
      sc: mobile ? 0.52 : 0.60,
      op: 1,
      lvl: pour.level
    }
  }

  onScroll() {
    if (!this.hasSentinelTarget) return
    const mid = window.innerHeight * 0.52
    let best = this.beat
    const rects = this.sentinelTargets.map((el) => el.getBoundingClientRect())

    for (let i = 0; i < rects.length; i++) {
      if (rects[i].top <= mid && rects[i].bottom >= mid) {
        best = i
        break
      }
    }
    if (rects[0] && rects[0].top > mid) best = 0
    if (rects[rects.length - 1] && rects[rects.length - 1].bottom < mid) best = rects.length - 1

    if (best !== this.beat) this.enterBeat(best, false)
  }

  onMouseMove(e) {
    if (this.reduced) return
    this.mx = (e.clientX / window.innerWidth - 0.5) * 2
    this.my = (e.clientY / window.innerHeight - 0.5) * 2
  }

  onKeyDown(e) {
    if (e.target.closest("input, textarea, button, a")) return
    const tRect = this.theatreTarget?.getBoundingClientRect()
    if (!tRect || tRect.bottom < window.innerHeight * 0.6) return
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
    const y = target.getBoundingClientRect().top + window.scrollY + (b === 0 ? 0 : 12)
    window.scrollTo({ top: y, behavior: this.reduced ? "auto" : "smooth" })
  }

  enterBeat(nextBeat, instant = false) {
    this.beat = nextBeat
    this.clearTimers()

    if (this.hasStageTarget) this.stageTarget.dataset.beat = String(nextBeat)
    this.copyTargets.forEach((el, i) => el.classList.toggle("is-active", i === nextBeat))
    this.railBtnTargets.forEach((el, i) => el.classList.toggle("is-active", i === nextBeat))

    const caps = [
      [ this.chosenDeck, "Click to preview slides" ],
      [ this.chosenDeck, "Click either flanking deck to swap" ],
      [ `Deck: ${this.chosenDeck}`, "Attached to Friday" ],
      [ `Presenting: ${this.chosenDeck}`, "Four pours, lowest proof first" ],
      [ "The tasting record", "Ranked by the room" ]
    ]
    if (this.hasDeckCapLTarget) this.deckCapLTarget.textContent = caps[nextBeat][0]
    if (this.hasDeckCapRTarget) this.deckCapRTarget.textContent = caps[nextBeat][1]

    this.gcapTargets.forEach((c) => c.classList.toggle("is-visible", nextBeat === 3))
    this.rankTargets.forEach((r) => r.classList.remove("is-visible"))
    this.glassTargets.forEach((g) => g.classList.remove("is-pouring"))

    const nowSec = performance.now() * 0.001

    this.gState.forEach((g, k) => {
      const dest = this.poseFor(nextBeat, k)
      g.from = { x: g.x, y: g.y, sc: g.sc, op: g.op, lvl: g.lvl }
      g.to = { ...dest }
      const midX = (g.from.x + dest.x) * 0.5
      const arcLift = nextBeat === 4 ? -11 - k * 2.5 : (nextBeat === 2 ? -8 : -5)
      g.ctrl = { x: midX + (nextBeat === 4 ? (k % 2 === 0 ? -5 : 5) : 0), y: Math.min(g.from.y, dest.y) + arcLift }

      const stagger = instant || this.reduced ? 0 : (nextBeat === 4 ? k * 0.075 : k * 0.055)
      g.tStart = nowSec + stagger
      g.dur = instant || this.reduced ? 0.001 : (nextBeat === 4 ? 0.86 : 0.72)
      g.active = true
      g.targetLvl = dest.lvl
      g.landedKick = false
    })

    // --- BEAT 3: Refined Sequential Living Pour (no cartoon dashed line!) ---
    if (nextBeat === 3) {
      POURS.forEach((pour, k) => {
        this.after(420 + k * 420, () => {
          if (this.beat !== 3) return
          const gEl = this.glassTargets[k]
          if (gEl) gEl.classList.add("is-pouring")
          this.gState[k].targetLvl = pour.level
          this.gState[k].sloshVel += (k % 2 === 0 ? 4.4 : -4.4)
          this.after(520, () => {
            if (gEl && this.beat === 3) gEl.classList.remove("is-pouring")
          })
        })
      })
    }

    // --- BEAT 4: Mid-Air Sort -> Ranked Podium -> Staggered Palate Wheel Bloom ---
    if (nextBeat === 4) {
      if (!this.reduced) {
        this.wedgeTargets.forEach((w) => {
          w.style.transitionDelay = "0ms"
          w.style.transform = "scale(0.08)"
          w.style.opacity = "0"
        })
      }
      this.after(560, () => {
        if (this.beat !== 4) return
        this.rankTargets.forEach((r) => r.classList.add("is-visible"))
      })
      this.after(700, () => {
        if (this.beat !== 4) return
        this.applyWheel(3, true)
      })
    }

    if (nextBeat === 2 && !instant) {
      this.after(300, () => {
        this.gState.forEach((g, k) => { g.sloshVel += (k - 1.5) * 1.8 })
      })
    }
  }

  // --- Interactive Actions ---
  nextSlide() {
    if (!this.dslideTargets.length) return
    // Hide temporary swapped cover overlay if cycling through real hero slides
    if (this.hasSwapCoverTarget) this.swapCoverTarget.hidden = true
    this.slideIdx = (this.slideIdx + 1) % this.dslideTargets.length
    this.dslideTargets.forEach((s, i) => s.classList.toggle("is-active", i === this.slideIdx))
    this.gState[0].sloshVel += 2.8
  }

  // Real physical 3D deck-swap animation when clicking either flanking deck in Beat 1!
  swapDeck(event) {
    if (this.swapping) return
    const btn = event.currentTarget
    const newTitle = btn.dataset.title
    const newCat = btn.dataset.category || "Whiskey"
    const newCover = btn.dataset.cover || ""
    if (!newTitle) return

    this.swapping = true
    const oldTitle = this.chosenDeck
    const oldCover = this.currentCover || this.element.dataset.initialCover || ""
    const oldCat = this.currentCategory || this.element.dataset.initialCategory || "Featured"

    // 1. Fly the clicked flanking card toward center
    btn.classList.add("is-swapping")

    setTimeout(() => {
      // 2. Swap state between center spotlight & clicked flank
      this.chosenDeck = newTitle
      this.currentCover = newCover
      this.currentCategory = newCat

      // Update center deck titles everywhere
      this.deckTitleTargets.forEach((el) => { el.textContent = newTitle })
      if (this.hasDeckCapLTarget) this.deckCapLTarget.textContent = newTitle

      // Show swapped deck's real cover image (or stylized cover) inside the center screen!
      if (this.hasSwapCoverTarget) {
        const img = this.swapCoverTarget.querySelector("img")
        const titleEl = this.swapCoverTarget.querySelector("[data-swap-title]")
        const catEl = this.swapCoverTarget.querySelector("[data-swap-cat]")
        if (newCover && img) {
          img.src = newCover
          img.hidden = false
        } else if (img) {
          img.hidden = true
        }
        if (titleEl) titleEl.textContent = newTitle
        if (catEl) catEl.textContent = newCat
        this.swapCoverTarget.hidden = false
      }

      // Put the previous center deck onto the clicked flank so it genuinely traded places!
      btn.dataset.title = oldTitle
      btn.dataset.category = oldCat
      btn.dataset.cover = oldCover
      const flankTitle = btn.querySelector("strong")
      const flankCat = btn.querySelector(".c4-sib-art span")
      const flankImg = btn.querySelector(".c4-sib-art img")
      if (flankTitle) flankTitle.textContent = oldTitle
      if (flankCat) flankCat.textContent = oldCat
      if (flankImg && oldCover) flankImg.src = oldCover

      // 3. Pop the center deck with 3D spring settle + kick the glass!
      if (this.hasDeckTarget) {
        this.deckTarget.classList.remove("is-swapped")
        void this.deckTarget.offsetWidth
        this.deckTarget.classList.add("is-swapped")
        setTimeout(() => this.deckTarget?.classList.remove("is-swapped"), 520)
      }
      this.gState[0].sloshVel += 4.6
      this.gState[0].targetLvl = Math.min(0.68, this.gState[0].targetLvl + 0.1)

      btn.classList.remove("is-swapping")
      this.swapping = false
    }, this.reduced ? 0 : 250)
  }

  toggleRsvp() {
    this.rsvpIn = !this.rsvpIn
    if (this.hasRsvpChipTarget) {
      this.rsvpChipTarget.classList.toggle("is-in", this.rsvpIn)
      this.rsvpChipTarget.textContent = this.rsvpIn ? "Seat saved · 6 going ✓" : "Save my seat"
    }
    this.gState.forEach((g, k) => {
      g.sloshVel += (k % 2 === 0 ? 4.2 : -4.2)
      g.targetLvl = this.rsvpIn ? 0.88 : 0.72
    })
  }

  tapGlass(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (this.beat === 3) {
      const gEl = this.glassTargets[idx]
      if (gEl) {
        gEl.classList.add("is-pouring")
        setTimeout(() => gEl.classList.remove("is-pouring"), 520)
      }
      this.gState[idx].sloshVel += 5.6
      this.nextSlide()
    } else if (this.beat === 4) {
      this.applyWheel(idx, false)
      this.gState[idx].sloshVel += 5.0
    }
  }

  hoverRank(event) {
    if (this.beat !== 4) return
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (idx !== this.activeWheelIdx) {
      this.applyWheel(idx, false)
      this.gState[idx].sloshVel += 3.4
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
      w.style.transitionDelay = staggered && !this.reduced ? `${i * 50}ms` : "0ms"
      w.style.transform = `scale(${(0.24 + v * 0.76).toFixed(3)})`
      w.style.opacity = (0.25 + v * 0.75).toFixed(2)
      w.setAttribute("fill", v >= 0.72 ? "#ff6d00" : (v >= 0.5 ? "#16332a" : "#8fa397"))
    })
  }

  drawLiquid(svgEl, level, slosh, phase, mode) {
    svgEl.classList.toggle("is-cream", mode === "dark")
    svgEl.classList.toggle("is-on-orange", mode === "orange")

    // On orange bg, make sure the white bowl fill sits BEHIND the liquid group
    if (mode === "orange" && !svgEl.dataset.orangeBacked) {
      const bowlPath = svgEl.querySelector('path[stroke="#16332a"][fill="none"]:not([stroke-opacity])')
      const liqGroup = svgEl.querySelector("g")
      if (bowlPath && liqGroup) {
        const bg = bowlPath.cloneNode(false)
        bg.setAttribute("fill", "#f6f4ee")
        bg.setAttribute("stroke", "none")
        bg.setAttribute("data-orange-bg", "1")
        svgEl.insertBefore(bg, liqGroup)
      }
      svgEl.dataset.orangeBacked = "1"
    }
    const bgPath = svgEl.querySelector("[data-orange-bg]")
    if (bgPath) bgPath.style.display = mode === "orange" ? "" : "none"

    const body = svgEl.querySelector("g > path")
    if (!body) return
    const lvl = clamp(level, 0, 1)
    if (lvl < 0.02) { body.setAttribute("d", ""); return }

    const baseY = 58.5 - lvl * 24
    const tilt = clamp(slosh, -6.5, 6.5)
    const wave = Math.sin(phase) * (0.85 + Math.abs(tilt) * 0.22)
    const yL = (baseY - tilt + wave).toFixed(2)
    const yM1 = (baseY - tilt * 0.35 - wave * 1.1).toFixed(2)
    const yM2 = (baseY + tilt * 0.35 + wave * 1.1).toFixed(2)
    const yR = (baseY + tilt - wave).toFixed(2)

    body.setAttribute("d", `M 6 ${yL} C 18 ${yM1}, 38 ${yM2}, 54 ${yR} L 54 70 L 6 70 Z`)
    body.setAttribute("fill", mode === "dark" ? "#ff6d00" : "#e65c00")
  }

  loop(now) {
    if (!this.running) return
    const t = now * 0.001

    if (!this.reduced) {
      this.curMx += (this.mx - this.curMx) * 0.08
      this.curMy += (this.my - this.curMy) * 0.08
    }

    if (this.hasDeckShellTarget) {
      const tiltAmt = this.beat === 0 ? 7 : (this.beat === 3 ? 2.5 : 1.5)
      this.deckShellTarget.style.transform = `rotateX(${(-this.curMy * tiltAmt).toFixed(2)}deg) rotateY(${(this.curMx * tiltAmt).toFixed(2)}deg)`
    }
    if (this.hasDeckSheenTarget) {
      this.deckSheenTarget.style.setProperty("--sx", `${(50 + this.curMx * 32).toFixed(1)}%`)
      this.deckSheenTarget.style.setProperty("--sy", `${(35 + this.curMy * 28).toFixed(1)}%`)
    }

    const mode = this.beat >= 3 ? "dark" : (this.beat === 2 ? "orange" : "paper")

    this.gState.forEach((g, k) => {
      if (g.active) {
        const raw = (t - g.tStart) / g.dur
        if (raw >= 0) {
          const u = easeOutCubic(clamp(raw, 0, 1))
          const inv = 1 - u
          g.x = inv * inv * g.from.x + 2 * inv * u * g.ctrl.x + u * u * g.to.x
          g.y = inv * inv * g.from.y + 2 * inv * u * g.ctrl.y + u * u * g.to.y
          g.sc = lerp(g.from.sc, g.to.sc, easeOutBack(clamp(raw, 0, 1)))
          g.op = lerp(g.from.op, g.to.op, clamp(raw * 1.4, 0, 1))
          const dx = g.to.x - g.from.x
          g.rot = Math.sin(u * Math.PI) * clamp(dx * 0.14, -7, 7)

          if (raw >= 1) {
            g.active = false
            g.x = g.to.x; g.y = g.to.y; g.sc = g.to.sc; g.op = g.to.op; g.rot = 0
            if (!g.landedKick && !this.reduced) {
              g.landedKick = true
              g.sloshVel += (k % 2 === 0 ? 4.2 : -4.2)
            }
          }
        }
      }

      g.lvl += (g.targetLvl - g.lvl) * (this.reduced ? 1 : 0.085)

      if (!this.reduced) {
        g.sloshVel += -g.slosh * 0.14
        g.sloshVel *= 0.87
        g.slosh += g.sloshVel * 0.17
      }

      const el = this.glassTargets[k]
      if (el) {
        const px = g.x + (this.beat === 3 ? this.curMx * (1.1 + k * 0.2) : 0)
        const py = g.y + (this.beat === 3 ? this.curMy * 0.6 : 0)
        el.style.opacity = g.op.toFixed(3)
        el.style.pointerEvents = g.op > 0.4 ? "auto" : "none"
        el.style.transform = `translate3d(calc(-50% + ${px.toFixed(2)}vw), calc(-50% + ${py.toFixed(2)}vh), 0) scale(${g.sc.toFixed(3)}) rotate(${g.rot.toFixed(2)}deg)`
        const svg = el.querySelector("svg")
        if (svg) this.drawLiquid(svg, g.lvl, g.slosh + Math.sin(t * 2.1 + k * 1.5) * 0.35, t * 4.2 + k * 1.2, mode)
      }
    })

    if (this.hasRestGlassTarget) {
      const rsvg = this.restGlassTarget.querySelector("svg")
      if (rsvg) this.drawLiquid(rsvg, 0.94, Math.sin(t * 1.8) * 0.45, t * 3.1, "paper")
    }

    this.raf = requestAnimationFrame(this.loop)
  }
}
