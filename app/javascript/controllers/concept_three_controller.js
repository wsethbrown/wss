import { Controller } from "@hotwired/stimulus"

// Concept 3: "The Living Pour" (/concepts/3)
// Full-viewport 60fps spring-interpolated shared-element choreography +
// live fluid-wave simulation inside every Glencairn glass!
//
// Timeline P in [0, 4]:
//   P = 0 : Hero (3D mouse-tilting Deck Slide on right, Editorial Headline on left,
//           1 empty Glencairn resting quietly at baseline)
//   P = 1 : Library (Hero Slide shrinks & slots center between 2 flying sibling decks;
//           Glencairn glides center-bottom and begins filling)
//   P = 2 : Society Invite (Room floods with vivid #ff6d00 orange; living-room photo
//           unveils above; Hero Slide pins itself onto top-right of the invite;
//           4 Glencairn glasses spring out in a celebratory arc)
//   P = 3 : Pour & Present (Lights dim to deep bottle-green #0b1b16; Oak table rises;
//           Hero Slide zooms back up into full living-room projection; 4 glasses land
//           across the table and fill sequentially via an animated pouring stream!)
//   P = 4 : The Verdict (Mid-Air Sort! The 4 filled glasses fly from serve order
//           left-to-right into winner order top-to-bottom on the left, while the
//           Palate Wheel blooms on the right and responds live to hovering any pour!)

const POURS = [
  { name: "Buffalo Trace",          proof: "90°",    score: "4.10", level: 0.72, rank: 3, wheel: [0.85, 0.52, 0.36, 0.72, 0.14, 0.50, 0.44, 0.10] },
  { name: "Maker's Mark 46",        proof: "94°",    score: "4.25", level: 0.78, rank: 2, wheel: [0.92, 0.80, 0.48, 0.62, 0.20, 0.42, 0.35, 0.10] },
  { name: "Heaven Hill 7yr BiB",    proof: "100°",   score: "4.40", level: 0.85, rank: 1, wheel: [0.76, 0.85, 0.72, 0.45, 0.24, 0.65, 0.25, 0.12] },
  { name: "Wild Turkey Rare Breed", proof: "116.8°", score: "4.65", level: 0.94, rank: 0, wheel: [0.72, 0.96, 0.92, 0.58, 0.42, 0.55, 0.20, 0.18] }
]

const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v))
const lerp = (a, b, t) => a + (b - a) * t
const ease = (t) => { const c = clamp(t); return c < 0.5 ? 4 * c * c * c : 1 - Math.pow(-2 * c + 2, 3) / 2 }
const band = (p, a, b) => ease((p - a) / (b - a))

export default class extends Controller {
  static targets = [
    "track", "stage",
    "bgOrange", "bgRoom", "bgVerdict", "tablePlane", "inviteBackdrop",
    "copy", "scrollCue", "railDot",
    "heroDeck", "deckShell", "deckSheen", "deckSlide", "deckCapL", "deckCapR",
    "sibLeft", "sibRight",
    "pourStream", "glass", "glassCaption", "rankCard",
    "wheelWrap", "wheelTitle", "wheelScore", "wedge",
    "restGlass"
  ]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.targetP = 0
    this.P = 0
    this.prevP = 0
    this.slosh = 0
    this.sloshVel = 0
    this.mx = 0
    this.my = 0
    this.curMx = 0
    this.curMy = 0
    this.t = 0
    this.slideIdx = 0
    this.activeWheelIdx = 3
    this.running = true

    this.onScroll = this.onScroll.bind(this)
    this.onMouseMove = this.onMouseMove.bind(this)
    this.loop = this.loop.bind(this)

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    window.addEventListener("mousemove", this.onMouseMove, { passive: true })

    this.applyWheel(3)
    this.onScroll()
    this.P = this.targetP
    this.raf = requestAnimationFrame(this.loop)
  }

  disconnect() {
    this.running = false
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    window.removeEventListener("mousemove", this.onMouseMove)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  onScroll() {
    if (!this.hasTrackTarget) return
    const rect = this.trackTarget.getBoundingClientRect()
    const scrollable = Math.max(1, this.trackTarget.offsetHeight - window.innerHeight)
    this.targetP = clamp(-rect.top / scrollable, 0, 1) * 4
  }

  onMouseMove(e) {
    if (this.reduced) return
    this.mx = (e.clientX / window.innerWidth - 0.5) * 2
    this.my = (e.clientY / window.innerHeight - 0.5) * 2
  }

  nextSlide() {
    if (!this.deckSlideTargets.length) return
    this.slideIdx = (this.slideIdx + 1) % this.deckSlideTargets.length
    this.deckSlideTargets.forEach((s, i) => s.classList.toggle("is-active", i === this.slideIdx))
    // Kick a tiny celebratory liquid slosh on click
    this.sloshVel += 2.6
  }

  jumpBeat(event) {
    const beat = parseInt(event.currentTarget.dataset.beat, 10)
    if (!this.hasTrackTarget) return
    const top = this.trackTarget.getBoundingClientRect().top + window.scrollY
    const scrollable = Math.max(1, this.trackTarget.offsetHeight - window.innerHeight)
    window.scrollTo({ top: top + (beat / 4) * scrollable, behavior: this.reduced ? "auto" : "smooth" })
  }

  focusVerdict(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (idx === this.activeWheelIdx) return
    this.applyWheel(idx)
    this.sloshVel += 2.2
  }

  applyWheel(idx) {
    this.activeWheelIdx = idx
    const pour = POURS[idx] || POURS[3]
    this.rankCardTargets.forEach((c) => c.classList.toggle("is-active", parseInt(c.dataset.index, 10) === idx))
    if (this.hasWheelTitleTarget) this.wheelTitleTarget.textContent = pour.name
    if (this.hasWheelScoreTarget) this.wheelScoreTarget.textContent = `${pour.score} / 5`
    this.wedgeTargets.forEach((w, i) => {
      const v = pour.wheel[i] ?? 0.25
      w.style.transform = `scale(${(0.24 + v * 0.76).toFixed(3)})`
      w.style.opacity = (0.25 + v * 0.75).toFixed(2)
      w.setAttribute("fill", v >= 0.72 ? "#ff6d00" : (v >= 0.5 ? "#16332a" : "#8fa397"))
    })
  }

  // Draw live wavy sloshing liquid path inside shared/_glass (viewBox 0 0 60 80)
  renderGlassLiquid(svgEl, level, sloshAngle, phase, creamMode) {
    svgEl.classList.toggle("is-cream", creamMode)
    const body = svgEl.querySelector("g > path")
    if (!body) return

    const lvl = clamp(level, 0, 1)
    if (lvl < 0.02) {
      body.setAttribute("d", "")
      return
    }

    const baseY = 58.5 - lvl * 24
    const tilt = clamp(sloshAngle, -6.5, 6.5)
    const wave = Math.sin(phase) * (0.9 + Math.abs(tilt) * 0.22)
    const yL = (baseY - tilt + wave).toFixed(2)
    const yM1 = (baseY - tilt * 0.35 - wave * 1.1).toFixed(2)
    const yM2 = (baseY + tilt * 0.35 + wave * 1.1).toFixed(2)
    const yR = (baseY + tilt - wave).toFixed(2)

    const surf = `M 6 ${yL} C 18 ${yM1}, 38 ${yM2}, 54 ${yR}`
    body.setAttribute("d", `${surf} L 54 70 L 6 70 Z`)
    body.setAttribute("fill", creamMode ? "#ff6d00" : "#e65c00")
  }

  loop(now) {
    if (!this.running) return
    this.t = now * 0.001

    // Smooth spring-damped scroll progress
    if (this.reduced) {
      this.P = this.targetP
    } else {
      this.P += (this.targetP - this.P) * 0.12
    }
    const dp = this.P - this.prevP
    this.prevP = this.P

    // Real damped spring slosh physics driven by scroll velocity!
    if (!this.reduced) {
      this.sloshVel += dp * 145
      this.sloshVel += -this.slosh * 0.14
      this.sloshVel *= 0.86
      this.slosh += this.sloshVel * 0.16
      this.curMx += (this.mx - this.curMx) * 0.08
      this.curMy += (this.my - this.curMy) * 0.08
    }

    const p = this.P
    const vw = window.innerWidth
    const vh = window.innerHeight
    const mobile = vw < 900

    // --- 1. Room Atmosphere Cross-Blends ---
    const orangeIn = band(p, 1.55, 2.0) * (1 - band(p, 2.48, 2.95))
    const roomIn = band(p, 2.48, 2.95) * (1 - band(p, 3.55, 3.92))
    const verdictIn = band(p, 3.55, 3.92)
    if (this.hasBgOrangeTarget) this.bgOrangeTarget.style.opacity = orangeIn.toFixed(3)
    if (this.hasBgRoomTarget) this.bgRoomTarget.style.opacity = roomIn.toFixed(3)
    if (this.hasBgVerdictTarget) this.bgVerdictTarget.style.opacity = verdictIn.toFixed(3)

    const isDark = p > 2.65
    if (this.hasStageTarget) this.stageTarget.dataset.tone = isDark ? "dark" : "light"
    if (this.hasScrollCueTarget) this.scrollCueTarget.style.opacity = (1 - band(p, 0.05, 0.35)).toFixed(3)

    // Right rail dots
    const activeBeat = Math.round(clamp(p, 0, 4))
    this.railDotTargets.forEach((d, i) => d.classList.toggle("is-active", i === activeBeat))

    // --- 2. Rising Oak Table Plane (Act 3) ---
    if (this.hasTablePlaneTarget) {
      const tbl = band(p, 2.55, 3.05) * (1 - band(p, 3.45, 3.85))
      this.tablePlaneTarget.style.transform = `translate3d(0, ${((1 - tbl) * 110).toFixed(1)}%, 0)`
      this.tablePlaneTarget.style.opacity = clamp(tbl * 1.4, 0, 1).toFixed(3)
    }

    // --- 3. Duotone Living Room Backdrop (Act 2 Invite) ---
    if (this.hasInviteBackdropTarget) {
      const inv = orangeIn
      const y = lerp(24, 0, inv)
      this.inviteBackdropTarget.style.opacity = inv.toFixed(3)
      this.inviteBackdropTarget.style.transform = `translate3d(0, ${y.toFixed(1)}px, 0) scale(${lerp(0.95, 1, inv).toFixed(3)})`
    }

    // --- 4. Editorial Copy Beats (0..4) ---
    const copyWindows = [
      [ -0.5, 0, 0.45 ],    // Beat 0: Hero
      [ 0.55, 1, 1.50 ],    // Beat 1: Library
      [ 1.55, 2, 2.48 ],    // Beat 2: Invite
      [ 2.58, 3, 3.48 ],    // Beat 3: Pour & Present
      [ 3.55, 4, 4.60 ]     // Beat 4: Verdict
    ]
    this.copyTargets.forEach((el, i) => {
      const [start, center, end] = copyWindows[i]
      let alpha = 0
      let dy = 0
      if (p <= center) {
        alpha = i === 0 ? 1 : band(p, start, center - 0.12)
        dy = (1 - alpha) * 28
      } else {
        alpha = 1 - band(p, center + 0.14, end)
        dy = -(1 - alpha) * 24
      }
      el.style.opacity = clamp(alpha, 0, 1).toFixed(3)
      el.classList.toggle("is-interactive", alpha > 0.65)
      if (i === 0) {
        el.style.transform = mobile ? `translate3d(0, ${dy.toFixed(1)}px, 0)` : `translate3d(0, calc(-50% + ${dy.toFixed(1)}px), 0)`
      } else if (i === 1 || i === 3) {
        el.style.transform = `translate3d(-50%, ${dy.toFixed(1)}px, 0)`
      } else {
        el.style.transform = `translate3d(0, ${dy.toFixed(1)}px, 0)`
      }
    })

    // --- 5. SHARED ELEMENT #1: THE HERO SLIDE (Flies across ALL 4 acts!) ---
    if (this.hasHeroDeckTarget) {
      // Keyframe poses [x(vw), y(vh), scale, rotDeg, opacity]
      const poses = mobile
        ? [
            [ 0,  16, 1.00,  0, 1 ],
            [ 0,   6, 0.88,  0, 1 ],
            [ 0, -14, 0.64,  0, 1 ],
            [ 0,  -8, 0.86,  0, 1 ],
            [ 0, -32, 0.72,  0, 0 ]
          ]
        : [
            [ 21,   2, 1.00,   0, 1 ], // P=0: Right side of hero
            [  0,   6, 0.68,   0, 1 ], // P=1: Center of 3-deck showcase
            [ 26,  14, 0.48,  -3, 1 ], // P=2: Pinned to lower-right of orange invite
            [  0,  -3, 0.82,   0, 1 ], // P=3: Living room projection screen!
            [  0, -24, 0.64,   0, 0 ]  // P=4: Lifts away for the verdict
          ]
      const seg = Math.min(3, Math.floor(clamp(p, 0, 3.999)))
      const localT = ease(p - seg)
      const A = poses[seg]
      const B = poses[seg + 1]
      const x = lerp(A[0], B[0], localT)
      const y = lerp(A[1], B[1], localT)
      const sc = lerp(A[2], B[2], localT)
      const rot = lerp(A[3], B[3], localT)
      const op = lerp(A[4], B[4], localT)

      this.heroDeckTarget.style.opacity = op.toFixed(3)
      this.heroDeckTarget.style.pointerEvents = op > 0.3 ? "auto" : "none"
      this.heroDeckTarget.style.transform = `translate3d(calc(-50% + ${x.toFixed(2)}vw), calc(-50% + ${y.toFixed(2)}svh), 0) scale(${sc.toFixed(3)}) rotate(${rot.toFixed(2)}deg)`

      // 3D mouse tilt strongest in Hero & Living Room
      if (this.hasDeckShellTarget) {
        const tiltAmt = (1 - band(p, 0.3, 0.9)) * 7 + roomIn * 3
        const rx = (-this.curMy * tiltAmt).toFixed(2)
        const ry = (this.curMx * tiltAmt).toFixed(2)
        this.deckShellTarget.style.transform = `rotateX(${rx}deg) rotateY(${ry}deg)`
      }
      if (this.hasDeckSheenTarget) {
        this.deckSheenTarget.style.setProperty("--sx", `${(50 + this.curMx * 32).toFixed(1)}%`)
        this.deckSheenTarget.style.setProperty("--sy", `${(35 + this.curMy * 28).toFixed(1)}%`)
      }

      // Sync caption & slide in Act 3
      const caps = [
        [ "Bourbon Basics", "24 slides · Click to flip" ],
        [ "Picked from the library", "Bourbon · $16.99" ],
        [ "Attached to Friday's night", "Deck ready" ],
        [ "Now presenting · Bourbon Basics", "Pour 1 – 4" ],
        [ "The tasting record", "Ranked" ]
      ]
      const ci = Math.round(clamp(p, 0, 4))
      if (this.hasDeckCapLTarget) this.deckCapLTarget.textContent = caps[ci][0]
      if (this.hasDeckCapRTarget) this.deckCapRTarget.textContent = caps[ci][1]
    }

    // Sibling decks gliding in beside Hero Slide in Beat 1
    const sibVis = band(p, 0.6, 0.98) * (1 - band(p, 1.28, 1.65))
    if (this.hasSibLeftTarget) {
      const lx = lerp(-52, -29, sibVis)
      this.sibLeftTarget.style.opacity = sibVis.toFixed(3)
      this.sibLeftTarget.style.transform = `translate3d(calc(-50% + ${lx.toFixed(1)}vw), calc(-50% + 9svh), 0) rotate(${lerp(-9, -4, sibVis).toFixed(1)}deg) scale(${lerp(0.84, 0.95, sibVis).toFixed(3)})`
    }
    if (this.hasSibRightTarget) {
      const rx = lerp(52, 29, sibVis)
      this.sibRightTarget.style.opacity = sibVis.toFixed(3)
      this.sibRightTarget.style.transform = `translate3d(calc(-50% + ${rx.toFixed(1)}vw), calc(-50% + 9svh), 0) rotate(${lerp(9, 4, sibVis).toFixed(1)}deg) scale(${lerp(0.84, 0.95, sibVis).toFixed(3)})`
    }

    // --- 6. SHARED ELEMENTS #2-#5: THE 4 LIVE SLOSHING GLENCAIRNS (Mid-Air Sort!) ---
    // Animated pouring stream in Beat 3 (appears as glasses fill 2.85 -> 3.40)
    if (this.hasPourStreamTarget) {
      const pourProg = clamp((p - 2.72) / 0.58, 0, 1)
      const activePourIdx = Math.min(3, Math.floor(pourProg * 4))
      const streamVis = (p > 2.74 && p < 3.34) ? Math.sin(((pourProg * 4) % 1) * Math.PI) : 0
      const tableXs = [ -24, -8, 8, 24 ]
      const sx = tableXs[activePourIdx]
      this.pourStreamTarget.style.opacity = (streamVis * 0.9).toFixed(3)
      this.pourStreamTarget.style.transform = `translate3d(calc(-50% + ${sx}vw), calc(-50% + 14svh), 0) scaleY(${(0.4 + streamVis * 0.7).toFixed(2)})`
    }

    this.glassTargets.forEach((el, k) => {
      const pour = POURS[k]
      // Keyframe poses [x(vw), y(vh), scale, opacity, level]
      const invX = [ -26, -18, -10, -2 ][k]
      const tblX = mobile ? [ -34, -11, 11, 34 ][k] : [ -24, -8, 8, 24 ][k]
      const sortY = [ -14, 1, 16, 31 ][pour.rank] // Sorted by WINNER rank!!
      const sortX = mobile ? -38 : -36

      const gPoses = [
        // P=0 Hero: Glass 0 sits quiet at bottom-left-center; 1-3 hidden behind it
        [ -2,  34, 0.72, k === 0 ? 0.95 : 0, 0.08 ],
        // P=1 Library: Glass 0 rises slightly & starts pouring
        [  0,  34, 0.76, k === 0 ? 1 : 0,    0.30 ],
        // P=2 Invite: All 4 glasses fan out along bottom-left of the orange invite!
        [ invX, 31, 0.62, 1, 0.55 ],
        // P=3 Living Room Table: All 4 drop onto the oak table & fill to their real pour levels!
        [ tblX, 27, mobile ? 0.68 : 0.96, 1, pour.level ],
        // P=4 Mid-Air Sort into Ranked Vertical Leaderboard on the Left!
        [ sortX, sortY, mobile ? 0.56 : 0.66, 1, pour.level ]
      ]

      const seg = Math.min(3, Math.floor(clamp(p, 0, 3.999)))
      // Stagger each glass slightly so they cascade organically instead of moving in lockstep
      const stagger = k * 0.055
      const localT = ease(clamp((p - seg - stagger) / (1 - 0.165), 0, 1))
      const A = gPoses[seg]
      const B = gPoses[seg + 1]

      const gx = lerp(A[0], B[0], localT) + (roomIn * this.curMx * (1.2 + k * 0.25))
      const gy = lerp(A[1], B[1], localT) + (roomIn * this.curMy * 0.8)
      const gsc = lerp(A[2], B[2], localT)
      const gop = lerp(A[3], B[3], localT)
      const glvl = lerp(A[4], B[4], localT)

      el.style.opacity = gop.toFixed(3)
      el.style.transform = `translate3d(calc(-50% + ${gx.toFixed(2)}vw), calc(-50% + ${gy.toFixed(2)}svh), 0) scale(${gsc.toFixed(3)})`

      // Render live sloshing liquid inside this glass's SVG
      const svg = el.querySelector("svg")
      if (svg) {
        const localSlosh = this.slosh + Math.sin(this.t * 2.2 + k * 1.4) * 0.45
        this.renderGlassLiquid(svg, glvl, localSlosh, this.t * 4.4 + k * 1.3, isDark)
      }

      // Show oak-table captions in Beat 3 only
      const cap = this.glassCaptionTargets[k]
      if (cap) cap.style.opacity = (roomIn > 0.65 ? 1 : 0)

      // Show sorted leaderboard cards in Beat 4 only
      const rc = this.rankCardTargets[k]
      if (rc) rc.classList.toggle("is-visible", verdictIn > 0.6)
    })

    // --- 7. SHARED ELEMENT #6: PALATE WHEEL (Blooms on right in Beat 4) ---
    if (this.hasWheelWrapTarget) {
      const wv = verdictIn
      this.wheelWrapTarget.style.opacity = wv.toFixed(3)
      this.wheelWrapTarget.classList.toggle("is-visible", wv > 0.6)
      this.wheelWrapTarget.style.transform = `translate3d(0, calc(-50% + ${((1 - wv) * 34).toFixed(1)}px), 0) scale(${lerp(0.86, 1, wv).toFixed(3)}) rotate(${lerp(-6, 0, wv).toFixed(2)}deg)`
    }

    // --- 8. Resting full Glencairn on top of Spotlight card (gentle live wave!) ---
    if (this.hasRestGlassTarget) {
      const rsvg = this.restGlassTarget.querySelector("svg")
      if (rsvg) this.renderGlassLiquid(rsvg, 0.94, this.slosh * 0.55, this.t * 3.2, false)
    }

    this.raf = requestAnimationFrame(this.loop)
  }
}
