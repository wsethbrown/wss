import { Controller } from "@hotwired/stimulus"

// The homepage story's frame (home/_story_frame.html.erb; content from
// StoryFrameHelper). One pinned screen whose objects travel from each step's
// arrangement to the next: the deck's slide shrinks into its row in the
// library, the row lifts into the invite, the invite opens onto the table,
// the glasses become the record.
//
// How it moves:
// - Every object's place, size, colour and text is a pure function of one
//   number, P (0 hero, 1 library, 2 invite, 3 table, 4 record). Each change
//   sits in its own window of the move with its own easing, so objects
//   overlap and settle rather than moving in lockstep.
// - The scroll only picks the current step. A step becomes current as the
//   top of its words nears the middle of the screen (ENTER), and stops being
//   current only once they fall back past ENTER + HYST.
// - The move to the current step then plays on a clock to the end (DUR per
//   move, eased overall), so a stopped scroll never leaves the frame half
//   way. Turning back mid-move reverses from where it is; a jump over several
//   steps is compressed (CATCH_UP). At the table step the glasses then fill
//   one after another on their own (FILL); at the record, once the card has
//   landed, its palate wheel draws on its own clock (WHEEL_*).
// - The clock advances by frame time, capped per frame, so a backgrounded
//   tab neither jumps nor stalls on return. Nothing runs per frame unless a
//   move, the fill or the wheel is playing, and nothing plays while the frame
//   is off screen (a step change there simply lands, the wheel drawn).
//
// Safety: the frame is aria-hidden and nothing in it takes focus; each
// step's static face carries the same content (the controller only adds
// .is-live, which keeps the faces for screen readers; see home/index).
// Without JS the faces simply show. Under reduced motion the frame shows
// each step's resting arrangement, with no travel. Before Turbo caches the
// page the frame is put at rest; disconnecting cancels every frame,
// listener and observer.

const ENTER = [ 0, 0.6, 0.6, 0.6, 0.6 ] // of the reading area, from its top
const HYST = 0.12
const DUR = [ 1.05, 1.25, 1.2, 1.3 ] // seconds: hero to library, library to invite, invite to table, table to record
const CATCH_UP = 1.5 // a jump over several steps takes no longer than this ...
const PER_STEP_MIN = 0.42 // ... unless each step would get less
const FILL = 2.4 // seconds: the glasses at the table, one after another
// The record's palate wheel, on its own clock once the record has arrived
// (never with the scroll): each lit wedge grows out from under the hub and
// takes its colour, one after another (a verdict night's pour by pour, each
// pour's in reading order round the wheel; a review's in reading order), then
// the labels fade in. Leaving the record it stays drawn until the card has
// sunk out of sight, then is ready to draw again.
const WHEEL_GROW = 0.9 // seconds: one wedge grows to full size
const WHEEL_TINT_LAG = 0.2 // seconds: its colour starts this long after it starts growing ...
const WHEEL_TINT = 0.9 // ... and takes this long
const WHEEL_STAGGER = 0.25 // seconds from one wedge to the next ...
const WHEEL_SPAN = 3 // ... less for a wheel with many wedges, so the last has its colour by this
const WHEEL_LABELS = 0.4 // seconds: the labels fade in as the last wedge starts to grow
const WHEEL_START = 0.56 // of the move to the record: the wheel starts as its card lands, not at the move's end
const CARD_RISE = [ 0.14, 0.56 ] // the record's card rises in this window of the table-to-record move
const MAX_DT = 0.05 // seconds: a frame never advances the clock by more
const H = 56.25 // the screen's height in cqw (16:9)
const WIDE = "(min-width: 900px)"
// How much of the window's height the phone band (with the nav above it) may
// take. It goes live at up to BAND_ENTER and keeps running up to BAND_EXIT, so
// the words below it always keep at least 40% and a window near the line
// never flips back and forth. Measured (November 2026): nav and band take 326px
// at 375 wide, 334px at 390 and 357px at 430, so the small viewports of an
// iPhone mini (375x635), an iPhone 13/14 (390x664) and a Pro Max (430x740)
// run the frame (51%, 50%, 48%); an iPhone SE (375x548, 59%) and any phone in
// landscape show the static faces.
const BAND_ENTER = 0.56
const BAND_EXIT = 0.6
// A wide window: room below the pinned frame to go live (it stops at none).
const PIN_ENTER = 16
// Letters as the reader sees them (an accented letter or an emoji is one).
const GRAPHEMES = typeof Intl !== "undefined" && Intl.Segmenter ? new Intl.Segmenter(undefined, { granularity: "grapheme" }) : null
const letters = (s) => (GRAPHEMES ? Array.from(GRAPHEMES.segment(s), (g) => g.segment) : [ ...s ])
// An element's place in the page by layout (the offsetTop chain), so a
// transform on it (the appear controller's rise) never moves the measure.
function docTop(el) {
  let y = 0
  for (let e = el; e; e = e.offsetParent) y += e.offsetTop
  return y
}

// Easing -----------------------------------------------------------------
function bezier(x1, y1, x2, y2) {
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
  const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
  const sx = (t) => ((ax * t + bx) * t + cx) * t
  const sy = (t) => ((ay * t + by) * t + cy) * t
  const dx = (t) => (3 * ax * t + 2 * bx) * t + cx
  return (x) => {
    if (x <= 0) return 0
    if (x >= 1) return 1
    let t = x
    for (let i = 0; i < 6; i++) {
      const e = sx(t) - x, d = dx(t)
      if (Math.abs(e) < 1e-5 || Math.abs(d) < 1e-6) break
      t -= e / d
    }
    if (t < 0 || t > 1) {
      let lo = 0, hi = 1
      t = x
      while (hi - lo > 1e-5) { if (sx(t) < x) lo = t; else hi = t; t = (lo + hi) / 2 }
    }
    return sy(t)
  }
}
const E = {
  travel: bezier(0.45, 0, 0.15, 1), // a carried object eases off, then settles long
  arcA: bezier(0.55, 0, 0.2, 1), // one axis leads ...
  arcB: bezier(0.3, 0, 0.35, 1), // ... the other lags, so the path bows
  lead: bezier(0.2, 0.6, 0.3, 1),
  lag: bezier(0.65, 0, 0.6, 1),
  out: bezier(0.23, 1, 0.32, 1), // --motion-ease-out
  pour: bezier(0.2, 0.7, 0.2, 1), // --motion-ease-pour
  fall: bezier(0.5, 0, 0.85, 0.5),
  lin: (t) => t
}
const PLAY = bezier(0.3, 0.12, 0.5, 1) // a whole move: under way at once, gentle settle
const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v)
const lerp = (a, b, t) => a + (b - a) * t
const band = (t, a, b, ease = E.travel) => ease(clamp01((t - a) / (b - a)))
const local = (P, i) => (P <= i ? 0 : P >= i + 1 ? 1 : P - i)
// One value per step; each change confined to its window of the move.
function tr(P, keys, bands, ease = E.travel) {
  if (P <= 0) return keys[0]
  if (P >= 4) return keys[4]
  const i = Math.floor(P), t = P - i
  const b = (bands && bands[i]) || [ 0, 1 ]
  const e = Array.isArray(ease) ? (ease[i] || E.travel) : ease
  return lerp(keys[i], keys[i + 1], band(t, b[0], Math.min(1, b[1]), e))
}
const hex = (h) => [ 1, 3, 5 ].map((i) => parseInt(h.slice(i, i + 2), 16))
const INK = hex("#16332a"), CREAM = hex("#f6f4ee"), MUTE = hex("#5f6b64"), DEEP = hex("#e65c00"), MARK = hex("#ff6d00"),
      SAGE = hex("#b8c9bf"), SOFT = hex("#ff8a33"), WHITE = hex("#ffffff")
// Mixed in OKLab, so a colour change never passes through a muddy middle.
const toLin = (c) => { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4 }
const toSrgb = (c) => Math.round(255 * Math.min(1, Math.max(0, c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055)))
function oklab([ r, g, b ]) {
  r = toLin(r); g = toLin(g); b = toLin(b)
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  return [ 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s ]
}
function mixOk(a, b, t) {
  const A = oklab(a), B = oklab(b), L = lerp(A[0], B[0], t), M = lerp(A[1], B[1], t), S = lerp(A[2], B[2], t)
  const l = (L + 0.3963377774 * M + 0.2158037573 * S) ** 3, m = (L - 0.1055613458 * M - 0.0638541728 * S) ** 3, s = (L - 0.0894841775 * M - 1.291485548 * S) ** 3
  return `rgb(${toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s)},${toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s)},${toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)})`
}
const mixc = (a, b, t, alpha = 1) =>
  `rgba(${Math.round(lerp(a[0], b[0], t))},${Math.round(lerp(a[1], b[1], t))},${Math.round(lerp(a[2], b[2], t))},${alpha})`

// Rolling text: the old text lifts away unit by unit (first half of the
// change), then the new rises into place unit by unit (second half). Units
// shared at the start of both stay put. Built from data-states with
// textContent only.
class Roll {
  constructor(el) {
    this.el = el
    this.states = JSON.parse(el.dataset.states || "[]")
    this.words = el.dataset.mode === "words"
    this.right = el.dataset.align === "right"
    el.textContent = ""
    this.lines = this.states.map((s) => {
      const line = document.createElement("span")
      line.className = "mm-rl"
      const units = this.words ? (s.match(/\S+\s*/g) || []) : letters(s)
      for (const u of units) {
        const span = document.createElement("span")
        span.className = "mm-ru"
        span.textContent = u
        line.appendChild(span)
      }
      el.appendChild(line)
      return { line, units: [ ...line.children ], w: 0 }
    })
    this.key = null
  }

  // Its width is its widest state's (a caption may then give way in the
  // bar, cut by CSS); each line is measured whole, never as cut.
  measure() {
    this.el.style.width = ""
    let max = 0
    for (const L of this.lines) {
      L.line.style.maxWidth = "none"
      L.w = L.line.offsetWidth
      L.line.style.maxWidth = ""
      max = Math.max(max, L.w)
    }
    this.el.style.width = `${Math.ceil(max + 1)}px`
    this.key = null
  }

  set(r) {
    const n = this.states.length - 1
    r = Math.max(0, Math.min(n, r))
    const i = Math.min(Math.floor(r), n)
    this.between(i, Math.min(i + 1, n), r - i)
  }

  between(a, b, p) {
    if (p >= 1) { a = b; p = 0 }
    const key = `${a}|${b}|${p.toFixed(4)}`
    if (key === this.key) return
    this.key = key
    const keep = a === b ? 0 : this.common(a, b)
    this.lines.forEach((L, j) => {
      if (j === a && (p === 0 || a !== b)) this.paint(L, p, -1, p > 0 ? keep : L.units.length + 1)
      else if (j === b && p > 0) this.paint(L, p, 1, keep)
      else if (L.v !== "hidden") { L.line.style.visibility = "hidden"; L.v = "hidden" }
    })
  }

  common(a, b) {
    if (this.right) return 0
    const x = this.lines[a].units, y = this.lines[b].units
    let k = 0
    while (k < x.length && k < y.length && x[k].textContent === y[k].textContent) k++
    return k
  }

  paint(L, p, dir, keep) {
    if (L.v !== "visible") { L.line.style.visibility = "visible"; L.v = "visible" }
    const moving = L.units.length - Math.min(keep, L.units.length)
    const spread = moving > 1 ? Math.min(0.45, 0.05 * moving) : 0
    L.units.forEach((u, k) => {
      let y = 0, o = 1
      if (k < keep) { if (dir > 0) o = 0 } else {
        const start = moving > 1 ? ((k - keep) / (moving - 1)) * spread : 0
        if (dir < 0) { const q = clamp01((p / 0.5 - start) / (1 - spread)); y = -E.travel(q) * 42; o = 1 - q } else {
          const q = clamp01(((p - 0.5) / 0.5 - start) / (1 - spread)); y = (1 - E.out(q)) * 42; o = clamp01(q * 1.6)
        }
      }
      const t = y ? `translateY(${y.toFixed(2)}%)` : "none"
      if (u.t !== t) { u.style.transform = t; u.t = t }
      const ov = o.toFixed(3)
      if (u.o !== ov) { u.style.opacity = ov; u.o = ov }
    })
  }
}

// One drawing of shared/_glass: level and tone set from here.
class Glass {
  constructor(host) {
    this.host = host
    this.liquid = host.querySelector("svg g > path")
    this.lv = this.c = null
  }

  level(v) {
    v = clamp01(v)
    if (v === this.lv || !this.liquid) return
    this.lv = v
    this.liquid.style.transform = `translateY(${((1 - v) * 28).toFixed(2)}px)` // shared/_glass: span 24, + 4 below the bowl
  }

  tone(c) { // 0 ink lines (on paper and orange), 1 cream lines (on green)
    c = clamp01(c)
    if (c === this.c) return
    this.c = c
    const s = this.host.style
    this.host.querySelector("svg").style.color = mixc(INK, CREAM, c)
    s.setProperty("--mm-liquid", mixc(DEEP, MARK, c))
    s.setProperty("--mm-under", (0.18 * (1 - c)).toFixed(3))
    s.setProperty("--mm-shine", mixc(WHITE, CREAM, c))
    s.setProperty("--mm-shine-o", lerp(0.6, 0.45, c).toFixed(3))
    s.setProperty("--mm-foot", (0.4 * (1 - c)).toFixed(3))
  }
}

export default class extends Controller {
  static targets = [ "frame", "screen", "beat" ]

  connect() {
    if (!this.hasFrameTarget || !this.hasScreenTarget || this.beatTargets.length < 5) return
    // Without these the frame cannot run safely: the static faces stay.
    if (typeof window.ResizeObserver !== "function" || typeof window.IntersectionObserver !== "function" || typeof window.matchMedia !== "function") {
      console.warn("Story frame: this browser lacks ResizeObserver, IntersectionObserver or matchMedia; showing the static faces")
      return
    }
    this.onScroll = this.onScroll.bind(this)
    this.onResize = this.onResize.bind(this)
    this.scheduleRelayout = this.scheduleRelayout.bind(this)
    this.tick = this.tick.bind(this)
    this.atRest = this.atRest.bind(this)
    this.onVisibility = this.onVisibility.bind(this)
    this.failed = false
    try {
      this.cfg = JSON.parse(this.frameTarget.dataset.config || "{}")
      this.reduce = window.matchMedia("(prefers-reduced-motion: reduce)")
      this.wide = window.matchMedia(WIDE)
      this.build()
      this.P = 0
      this.f = 0
      this.w = 0 // seconds into the wheel's drawing
      this.v = 0
      this.target = 0
      this.anim = null
      this.raf = null
      this.visible = true
      this.live = false
      this.cache = new Map()
      this.padding = document.documentElement.style.scrollPaddingTop
      this.inputs = null
      this.probeHeight()
      window.addEventListener("scroll", this.onScroll, { passive: true })
      window.addEventListener("resize", this.onResize)
      document.addEventListener("turbo:before-cache", this.atRest)
      document.addEventListener("visibilitychange", this.onVisibility)
      this.reduce.addEventListener?.("change", this.scheduleRelayout)
      this.wide.addEventListener?.("change", this.scheduleRelayout)
      // The screen's size and the story's height (a face shown by keyboard
      // focus, late fonts or images) both move the steps: measure again.
      // While the faces show, only a change in what decides it does anything.
      this.resizer = new ResizeObserver(() => (this.live ? this.scheduleRelayout() : this.onResize()))
      this.resizer.observe(this.screenTarget)
      this.resizer.observe(this.element)
      // Off screen, nothing plays: a step change there simply lands.
      this.seen = new IntersectionObserver((entries) => {
        for (const e of entries) this.visible = e.isIntersecting
        if (!this.visible) this.land()
        else this.kick() // the fill waits for the frame to be seen
      })
      this.seen.observe(this.screenTarget)
      if (document.fonts?.ready) document.fonts.ready.then(() => this.element.isConnected && this.scheduleRelayout())
      window.__storyFrame = this // read by the system tests
      this.start()
    } catch (error) {
      this.fail(error)
    }
  }

  disconnect() {
    this.teardown()
    if (window.__storyFrame === this) window.__storyFrame = null
  }

  teardown() {
    if (!this.onScroll) return
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("turbo:before-cache", this.atRest)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.reduce?.removeEventListener?.("change", this.scheduleRelayout)
    this.wide?.removeEventListener?.("change", this.scheduleRelayout)
    this.resizer?.disconnect()
    this.seen?.disconnect()
    if (this.raf) cancelAnimationFrame(this.raf)
    if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame)
    if (this.layoutFrame) cancelAnimationFrame(this.layoutFrame)
    this.raf = this.scrollFrame = this.layoutFrame = null
    this.anim = null
    // Holding the place only matters on a page still showing (a failure);
    // a controller leaving with its page has nothing to keep.
    this.goStatic(this.element.isConnected)
    this.probe?.remove()
    this.probe = null
  }

  // Anything thrown: stop, detach, and leave the static faces showing.
  fail(error) {
    console.error("Story frame: stopped, showing the static faces", error)
    this.failed = true
    this.teardown()
  }

  goStatic(hold = true) {
    const was = this.element.classList.contains("is-live")
    const restore = was && hold ? this.holdPlace() : null
    this.live = false
    this.element.classList.remove("is-live")
    if (this.padding !== undefined) document.documentElement.style.scrollPaddingTop = this.padding
    restore?.()
  }

  // Going live or static changes the story's height: the faces leave or
  // rejoin the flow and the steps are spaced for the frame or not. Keep what
  // the reader was looking at where it was: on opening, the element a
  // #fragment points at (so a link to /#pricing still lands on the pricing
  // rows); else, going
  // static, the words of the step the frame was showing; else, going live,
  // the words of the step being read (or the first section in view). Going
  // live on a phone, words that were in view are kept clear of the band.
  // Measured by layout, not by transform, so a reveal in flight never moves
  // it. Instant, never smooth, and before the appear controller sorts what is
  // on screen, so nothing that was in view starts hidden.
  holdPlace() {
    let target = null
    // A #fragment: on the first decision only (the page just opened at it),
    // land on it, wherever the browser had got to. Later the reader has moved on.
    if (this.inputs === null) {
      try { target = window.location.hash && document.getElementById(decodeURIComponent(window.location.hash.slice(1))) } catch (_) { target = null }
    }
    if (target) return () => target.scrollIntoView({ block: "start", behavior: "instant" })
    if (window.scrollY <= 0) return null
    const words = (b) => b.querySelector(".beat-body, h1, h2") || b
    const top = (el) => docTop(el) - window.scrollY
    const navBottom = this.navBottom || 0
    let anchor = null
    if (this.live) anchor = words(this.beatTargets[this.target] || this.beatTargets[0])
    else {
      // The step being read: the last whose words have come up into the top
      // 60% below the nav; else the first step or section still in view.
      const line = navBottom + (window.innerHeight - navBottom) * 0.6
      const steps = this.beatTargets.map(words).filter((el) => top(el) + el.offsetHeight > navBottom && top(el) <= line)
      anchor = steps[steps.length - 1] ||
        [ ...this.beatTargets.map(words), ...document.querySelectorAll("main section") ].find((el) => top(el) + el.offsetHeight > navBottom)
    }
    if (!anchor) return null
    const before = top(anchor)
    const wasInView = before >= navBottom && this.beatTargets.some((b) => words(b) === anchor)
    return () => {
      let want = before
      if (wasInView && this.element.classList.contains("is-live") && !this.wide.matches) {
        want = Math.max(want, this.navBottom + 8 + this.frameTarget.offsetHeight + 8)
      }
      const shift = top(anchor) - want
      if (Math.abs(shift) >= 1) window.scrollTo({ top: window.scrollY + shift, behavior: "instant" })
    }
  }

  // Across a change of layout while live: the current step's words keep their
  // place on screen where they can, within the stretch of scroll where pick()
  // still chooses that step (its words at or above its line plus HYST, the
  // next step's below its own line). Measured by layout; instant.
  keepStep() {
    const t = this.target
    const words = (b) => b.querySelector(".beat-body, h1, h2") || b
    const before = docTop(words(this.beatTargets[t])) - window.scrollY
    return () => {
      const a = this.area(), line = (i) => a.top + a.h * ENTER[i]
      const lo = t > 0 ? this.tops[t] - (line(t) + a.h * HYST) + 2 : 0
      const hi = t + 1 < this.tops.length ? this.tops[t + 1] - line(t + 1) - 2 : Infinity
      const y = Math.max(0, lo > hi ? (lo + hi) / 2 : Math.max(lo, Math.min(hi, this.tops[t] - before)))
      if (Math.abs(y - window.scrollY) >= 1) {
        console.info(`Story frame: the layout changed; keeping step ${t} current`)
        window.scrollTo({ top: y, behavior: "instant" })
      }
    }
  }

  // Run the frame if the window can hold it; otherwise the static faces.
  // Called once on connect and then only when what decides it has changed.
  start() {
    const restore = this.holdPlace()
    const first = this.inputs === null
    this.element.classList.add("is-live")
    this.measure()
    this.inputs = this.inputsKey()
    if (!this.fits(true)) {
      console.info(`Story frame: ${this.fitText()} cannot hold the frame; showing the static faces`)
      this.goStatic(false)
      restore?.()
      return
    }
    if (!first) console.info(`Story frame: ${this.fitText()} now holds the frame; running it`)
    restore?.()
    this.measure() // the steps' positions after the scroll is put back
    this.live = true
    this.pick()
    this.P = this.target
    this.f = this.target === 3 && this.reduce.matches ? 1 : 0
    this.w = this.target === 4 && this.reduce.matches ? this.wheelEnd : 0
    this.render()
    this.kick()
  }

  // A wide window holds the pinned frame below the nav; a narrow one keeps
  // enough of its height below the band for the words (BAND_ENTER, BAND_EXIT).
  // entering: the stricter test for going live; once live, the looser one.
  // Measured against the small viewport, so a phone's toolbar coming and
  // going never changes the answer.
  fits(entering = false) {
    const vh = this.stableHeight()
    if (this.wide.matches) return this.navBottom + 16 + this.frameTarget.querySelector(".mm-pin").offsetHeight + (entering ? PIN_ENTER : 0) <= vh
    return this.bandBottom() <= vh * (entering ? BAND_ENTER : BAND_EXIT)
  }

  bandBottom() { return this.navBottom + 8 + this.frameTarget.offsetHeight }

  fitText() {
    const vh = this.stableHeight()
    const used = this.wide.matches ? this.navBottom + 16 + this.frameTarget.querySelector(".mm-pin").offsetHeight : this.bandBottom()
    return `${window.innerWidth}px wide, ${vh}px tall (the frame takes ${used}px, ${Math.round((100 * used) / vh)}%)`
  }

  // The small viewport's height (100svh: the window with a phone's toolbar
  // showing), which stays put while the toolbar collapses and returns, unlike
  // innerHeight. Browsers without svh: the root's clientHeight.
  probeHeight() {
    if (!window.CSS?.supports?.("height", "100svh")) return
    this.probe = document.createElement("div")
    this.probe.setAttribute("aria-hidden", "true")
    this.probe.style.cssText = "position:fixed;left:0;top:0;width:0;height:100svh;visibility:hidden;pointer-events:none"
    document.body.appendChild(this.probe)
  }

  stableHeight() {
    const h = this.probe?.offsetHeight
    return h > 0 ? h : document.documentElement.clientHeight
  }

  // What decides live or static: the width and the stable height.
  inputsKey() { return `${window.innerWidth}x${this.stableHeight()}` }

  // A window resize that changes neither (a phone's toolbar) does nothing at all.
  onResize() {
    if (this.failed || this.inputsKey() === this.inputs) return
    this.scheduleRelayout()
  }

  scheduleRelayout() {
    if (this.layoutFrame || this.failed) return
    this.layoutFrame = requestAnimationFrame(() => { this.layoutFrame = null; this.relayout() })
  }

  // Objects ------------------------------------------------------------------
  build() {
    const q = (name) => this.frameTarget.querySelector(`[data-mm="${name}"]`)
    const all = (name) => [ ...this.frameTarget.querySelectorAll(`[data-mm="${name}"]`) ]
    const byK = (name) => { const out = []; for (const el of all(name)) out[+el.dataset.k] = el; return out }
    this.rolls = new Map()
    for (const el of this.frameTarget.querySelectorAll(".mm-roll")) this.rolls.set(el, new Roll(el))
    const roll = (host) => host && this.rolls.get(host.matches(".mm-roll") ? host : host.querySelector(".mm-roll"))
    this.el = {
      paper: q("paper"), oak: q("oak"), mark: q("mark"), photo: q("photo"), ph: q("ph"), card: q("card"), cardScore: q("card-score"),
      head: q("head"), heading: q("heading"), slide: q("slide"), lift: q("lift"), time: q("time"), tag: q("tag"), date: q("date"),
      title: q("title"), meta: q("meta"), going: q("going"), review: q("review"),
      rows: all("row"), glasses: byK("glass"), labels: byK("label"), scores: byK("score"), vlines: byK("vline"), bys: byK("by")
    }
    this.el.phImg = this.el.ph?.querySelector("img")
    this.roll = roll
    this.capL = roll(q("cap-l"))
    this.capR = roll(q("cap-r"))
    this.glassDrawings = this.el.glasses.map((g) => new Glass(g))
    // The wheel's wedges in the order they draw (by pour, then round the
    // wheel from the top, as the markup has them), each with its start time.
    this.wedges = [ ...this.frameTarget.querySelectorAll(".mm-card .wheel-wedge") ]
      .map((p, i) => ({ el: p, from: parseFloat(p.style.getPropertyValue("--from")) || 0.25, k: +(p.dataset.pour || 0), i, s: null, c: null }))
      .sort((a, b) => a.k - b.k || a.i - b.i)
    const n = this.wedges.length
    const stagger = n > 1 ? Math.min(WHEEL_STAGGER, (WHEEL_SPAN - WHEEL_TINT_LAG - WHEEL_TINT) / (n - 1)) : 0
    this.wedges.forEach((w, j) => { w.at = j * stagger })
    this.labelsAt = n ? (n - 1) * stagger : 0
    this.wheelEnd = n ? Math.max(this.labelsAt + WHEEL_LABELS, (n - 1) * stagger + WHEEL_TINT_LAG + WHEEL_TINT) : 0
    this.wheelLabels = [ ...this.frameTarget.querySelectorAll(".mm-card .wheel-label") ]
    // Nothing in the frame takes focus: it is presentational and moves.
    for (const el of this.frameTarget.querySelectorAll("a, button, [tabindex]")) el.setAttribute("tabindex", "-1")
  }

  measure() {
    this.u = this.screenTarget.offsetWidth / 100
    const nav = document.querySelector("body > nav, nav.fixed")
    this.navBottom = nav ? Math.round(nav.getBoundingClientRect().bottom) : 0
    this.element.style.setProperty("--mm-top", `${this.navBottom + 8}px`)
    const pin = this.frameTarget.querySelector(".mm-pin")
    this.element.style.setProperty("--mm-pin-h", `${pin.offsetHeight}px`)
    this.rolls.forEach((r) => r.measure())
    // Where each step's words start (the closing line has no .beat-body: its
    // heading), by layout: the appear controller's rise must not shift them.
    this.tops = this.beatTargets.map((b) => docTop(b.querySelector(".beat-body, h1, h2") || b))
    this.phone = !this.wide.matches
    // On a phone, keep anything focused or scrolled to clear of the band.
    document.documentElement.style.scrollPaddingTop = this.phone ? `${this.bandBottom() + 8}px` : this.padding
  }

  relayout() {
    if (!this.cfg || this.failed) return
    try {
      // Static: try again only if what decides it has changed.
      if (!this.live) return this.inputsKey() === this.inputs ? undefined : this.start()
      // A change of layout while live (a tablet turned, a window resized
      // across 900px or to another width) moves every step's words: keep the
      // current step current.
      const width = this.screenTarget.offsetWidth / 100
      const keep = this.phone !== !this.wide.matches || Math.abs(width - this.u) > 0.001 ? this.keepStep() : null
      this.measure()
      this.inputs = this.inputsKey()
      if (!this.fits()) {
        console.info(`Story frame: ${this.fitText()} can no longer hold the frame; showing the static faces`)
        this.anim = null
        if (this.raf) { cancelAnimationFrame(this.raf); this.raf = null }
        return this.goStatic()
      }
      keep?.()
      if (this.reduce.matches) { this.pick(); this.land() }
      this.cache.clear()
      this.rolls.forEach((r) => { r.key = null })
      this.draw()
      this.onScroll()
    } catch (error) {
      this.fail(error)
    }
  }

  // Every frame goes through here: a throw stops the frame and shows the faces.
  draw() {
    try {
      this.render()
    } catch (error) {
      this.fail(error)
    }
  }

  // Which step is current ------------------------------------------------------
  area() {
    const vh = window.innerHeight
    if (this.wide.matches) return { top: 0, h: vh }
    const bottom = Math.max(0, this.frameTarget.getBoundingClientRect().bottom)
    return { top: bottom, h: Math.max(1, vh - bottom) }
  }

  pick() {
    const a = this.area(), y = window.scrollY
    let up = 0, down = 0
    for (let i = 1; i < this.tops.length; i++) {
      const top = this.tops[i] - y
      if (top <= a.top + a.h * ENTER[i]) up = i
      if (top <= a.top + a.h * (ENTER[i] + HYST)) down = i
    }
    if (up > this.target) this.target = up
    else if (down < this.target) this.target = down
    return this.target
  }

  onScroll() {
    if (this.scrollFrame || !this.live) return
    this.scrollFrame = requestAnimationFrame(() => {
      this.scrollFrame = null
      const before = this.target
      this.pick()
      if (this.target !== before) this.retarget()
    })
  }

  // The clock ---------------------------------------------------------------
  legSeconds(from, to) {
    const lo = Math.min(from, to), hi = Math.max(from, to)
    let d = 0
    for (let i = 0; i < 4; i++) d += DUR[i] * Math.max(0, Math.min(hi, i + 1) - Math.max(lo, i))
    const steps = hi - lo
    return Math.max(0.3, steps > 1 ? Math.min(d, Math.max(CATCH_UP, PER_STEP_MIN * steps)) : d)
  }

  retarget() {
    if (this.reduce.matches || !this.visible || document.hidden) return this.land()
    if (this.anim ? this.anim.to === this.target : this.P === this.target) return this.kick()
    const T = this.legSeconds(this.P, this.target)
    // Passing on to a further step mid-move keeps its speed (a Hermite curve
    // from the current velocity), so it never stalls and restarts; turning
    // back starts from rest on the usual curve.
    const dir = Math.sign(this.target - this.P)
    const v0 = this.anim && Math.sign(this.v) === dir ? Math.min(Math.abs(this.v) * T, 2 * Math.abs(this.target - this.P)) * dir : 0
    this.anim = { from: this.P, to: this.target, elapsed: 0, T, v0 }
    this.kick()
  }

  // Straight to the current step's resting arrangement, no travel.
  land() {
    this.anim = null
    this.P = this.target
    if (this.P <= 2) this.f = 0
    if (this.P === 3 && this.reduce.matches) this.f = 1
    // At rest at the record its wheel is drawn; anywhere else it is ready to draw.
    this.w = this.P === 4 ? this.wheelEnd : 0
    if (this.raf) { cancelAnimationFrame(this.raf); this.raf = null }
    if (this.live) this.draw()
  }

  atRest() { if (this.live) this.land() }

  onVisibility() { if (!document.hidden) this.last = null }

  playing() { return !!this.anim || this.filling() || this.drawing() }

  filling() { return this.P === 3 && this.target === 3 && this.f < 1 && !this.reduce.matches }

  drawing() { return this.P >= 3 + WHEEL_START && this.target === 4 && this.w < this.wheelEnd && !this.reduce.matches }

  kick() {
    if (this.raf || !this.live || !this.playing() || !this.visible) return
    this.last = null
    this.raf = requestAnimationFrame(this.tick)
  }

  tick(now) {
    this.raf = null
    const dt = this.last == null ? 1 / 60 : Math.min(MAX_DT, (now - this.last) / 1000)
    this.last = now
    const before = this.P
    if (this.anim) {
      const a = this.anim
      a.elapsed += dt
      const e = clamp01(a.elapsed / a.T)
      if (a.v0) {
        const e2 = e * e, e3 = e2 * e
        this.P = (2 * e3 - 3 * e2 + 1) * a.from + (e3 - 2 * e2 + e) * a.v0 + (-2 * e3 + 3 * e2) * a.to
      } else {
        this.P = a.from + (a.to - a.from) * PLAY(e)
      }
      if (e >= 1) { this.P = a.to; this.anim = null }
    }
    this.v = dt > 0 ? (this.P - before) / dt : 0
    if (this.P <= 2) this.f = 0
    if (this.P === 3 && this.target === 3 && this.f < 1) this.f = Math.min(1, this.f + dt / FILL)
    // The wheel draws only once the record has arrived, and is put back only
    // once its card has sunk out of sight.
    if (this.P <= 3 + CARD_RISE[0]) this.w = 0
    else if (this.drawing()) this.w = Math.min(this.wheelEnd, this.w + dt)
    this.draw()
    if (this.live && this.playing() && this.visible) this.raf = requestAnimationFrame(this.tick)
  }

  // Drawing -------------------------------------------------------------------
  place(el, x, y, s = 1, o = 1, extra = "") {
    if (!el) return
    const u = this.u
    const t = `translate3d(${(x * u).toFixed(2)}px,${(y * u).toFixed(2)}px,0) scale(${s.toFixed(4)})${extra}`
    const c = this.cache.get(el) || {}
    if (c.t !== t) { el.style.transform = t; c.t = t }
    const ov = clamp01(o).toFixed(3)
    if (c.o !== ov) { el.style.opacity = ov; el.style.visibility = +ov <= 0.001 ? "hidden" : "visible"; c.o = ov }
    this.cache.set(el, c)
  }

  css(el, prop, value) {
    if (!el) return
    const c = this.cache.get(el) || {}
    if (c[prop] !== value) { el.style[prop] = value; c[prop] = value; this.cache.set(el, c) }
  }

  render() {
    const P = this.P, f = this.f, cfg = this.cfg, phone = this.phone
    const tBC = local(P, 1), tCD = local(P, 2), tDE = local(P, 3)
    const n = cfg.rows, p = cfg.picked, S = cfg.seats, T = cfg.table ?? cfg.invite_glasses, gI = cfg.invite_glasses, gR = cfg.record_glasses
    const kind = cfg.record, verdict = kind === "verdict", reviewed = kind === "review", listed = kind === "reviews"
    // The record as rows (a verdict night's pours, or each drink with its
    // review), and the review's card on the right (one review, or the first row's).
    const rowsShown = verdict || listed, carded = reviewed || listed
    const wheelCard = (verdict && cfg.wheel) || listed
    // Where a record's row starts (its rule), and its glass, name, score and reviewer within it.
    const ROW = listed ? { top: 13.4, step: 9.4, glass: 1.6, label: 1.4, score: 3.1, by: 5.1 } : { top: 21.3, step: 7.6, glass: 1.1, label: 2.6, score: 2.6, by: 0 }
    const rowY = (k, part) => ROW.top + ROW.step * k + (part ? ROW[part] : 0)
    const rowTop = (i) => 53 - 12 * (n - i)
    const pTop = n ? rowTop(p) : 29
    const seat = (k) => ((k + 0.5) * 100) / Math.max(1, T)

    // The slide: the lead of every move.
    {
      const bands = [ [ 0, 0.78 ], [ 0.3, 0.8 ], [ 0.36, 0.94 ], [ 0, 0.36 ] ]
      const inInvite = cfg.slide_in_invite
      const inRecord = verdict && cfg.slide_in_record
      const cx = inInvite ? 5 : 12, cy = inInvite ? 33.3 : pTop + 4.5, cs = inInvite ? 0.14 : 0.05
      const ex = inRecord ? 5 : 30, ey = inRecord ? 11.2 : 20, es = inRecord ? 0.09 : 0.04
      const x = tr(P, [ 0, 7, cx, 4, ex ], bands, [ E.arcA, E.travel, E.arcB, E.arcA ])
      const y = tr(P, [ 0, pTop + 2.06, cy, 4.2, ey ], bands, [ E.arcB, E.travel, E.lead, E.arcB ])
      const s = tr(P, [ 1, 0.14, cs, 0.58, es ], bands, E.travel)
      const o = tr(P, [ 1, 1, inInvite ? 1 : 0, 1, inRecord ? 1 : 0 ], [ null, [ 0.3, 0.6 ], [ 0.36, 0.6 ], [ 0.05, 0.36 ] ], E.lin)
      this.place(this.el.slide, x, y, s, o)
      const i = Math.min(3, Math.floor(P)), t = P - i
      const lift = P <= 0 || P >= 4 ? 0 : Math.sin(Math.PI * band(t, bands[i][0], bands[i][1], E.lin))
      this.css(this.el.lift, "opacity", lift.toFixed(3))
    }

    this.css(this.el.paper, "visibility", P < 1.9 ? "visible" : "hidden")

    // Orange: the picked row fills like a pour, opens into the invite, then
    // drains downward onto the table, which sinks away for the record.
    let edge = -1e9
    {
      let o = 0, ty = 0
      if (P > 1 && P < 2) {
        const p1 = band(tBC, 0.1, 0.4), p2 = band(tBC, 0.36, 0.84)
        o = tBC > 0.1 ? 1 : 0
        const u = this.u, x0 = lerp(5.6, -4, p2), y0 = lerp(pTop + 0.6, -4, p2), x1 = lerp(lerp(5.6, 94.4, p1), 104, p2), y1 = lerp(pTop + 11.8, H + 4, p2)
        const clip = `inset(${(y0 * u).toFixed(2)}px ${((100 - x1) * u).toFixed(2)}px ${((H - y1) * u).toFixed(2)}px ${(x0 * u).toFixed(2)}px round ${(lerp(1.4, 0, p2) * u).toFixed(2)}px)`
        if (o) this.css(this.el.mark, "clipPath", clip)
      } else if (P >= 2 && P < 3) {
        o = 1
        // It drains in the first half of the move, while the glasses are
        // still on their way to their seats, so no stripe lingers under the table.
        ty = H * band(tCD, 0.04, 0.55)
        this.css(this.el.mark, "clipPath", "none")
      }
      if (ty >= H - 0.01) o = 0
      edge = P < 2 ? -1e9 : (o ? ty : H + 5)
      this.css(this.el.mark, "visibility", o ? "visible" : "hidden")
      this.css(this.el.mark, "transform", `translate3d(0,${(ty * this.u).toFixed(2)}px,0)`)
      const tt = P > 3 && P < 4 ? (H - 43.6) * band(tDE, 0.12, 0.5) : 0
      this.css(this.el.oak, "visibility", P >= 2 && P < 4 ? "visible" : "hidden")
      this.css(this.el.oak, "transform", `translate3d(0,${(tt * this.u).toFixed(2)}px,0)`)
    }
    const onInk = (yc) => (P < 2 ? 0 : clamp01((edge - yc) / 2.4 + 0.5))

    // The photograph slides down into its band and settles, then slides back up.
    {
      let h = 0, sc = 1
      if (P > 1 && P < 2) { h = 26.4 * band(tBC, 0.34, 0.9); sc = lerp(1.08, 1, band(tBC, 0.34, 1, E.pour)) } else if (P >= 2 && P < 3) { h = 26.4 * (1 - band(tCD, 0.04, 0.6)); sc = lerp(1, 1.04, band(tCD, 0, 0.6, E.lin)) }
      this.css(this.el.photo, "visibility", h > 0.01 ? "visible" : "hidden")
      if (h > 0.01) {
        this.css(this.el.ph, "transform", `translate3d(0,${((h - 26.4) * this.u).toFixed(2)}px,0)`)
        this.css(this.el.phImg, "transform", `scale(${sc.toFixed(4)})`)
      }
    }

    // The library: heading and the rows that were not picked.
    this.roll(this.el.head)?.set(tr(P, [ 0, 1, 2, 2, 2 ], [ [ 0.34, 0.92 ], [ 0, 0.42 ] ], E.lin))
    this.place(this.el.head, 7, 5.4)
    for (const row of this.el.rows) {
      const i = +row.dataset.row, y = rowTop(i), picked = i === p
      const away = i < p ? -1.2 : 1.4
      const inA = 0.3 + 0.06 * i, outB = 0.04 * Math.abs(i - p)
      this.place(row, 7, tr(P, [ y + 4, y, picked ? y : y + 5, y + 5, y + 5 ], [ [ inA, inA + 0.48 ], [ outB, outB + 0.34 ] ], [ E.pour, E.fall ]),
        1, tr(P, [ 0, 1, 0, 0, 0 ], [ [ inA, inA + 0.4 ], picked ? [ 0.12, 0.3 ] : [ outB, outB + 0.34 ] ], E.lin),
        picked ? "" : ` rotate(${tr(P, [ 0, 0, away, away, away ], [ null, [ outB, outB + 0.34 ] ], E.fall).toFixed(2)}deg)`)
    }

    // The deck's title: its row, the night's heading, then the record's line.
    {
      const bands = [ [ 0.36, 0.86 ], [ 0.28, 0.84 ], [ 0, 0.42 ], [ 0.02, 0.36 ] ]
      const ex = reviewed ? 7 : (verdict && cfg.slide_in_record ? 15.6 : 5), ey = reviewed ? 25.2 : 10.9, es = reviewed ? 1.15 : 0.6
      const x = tr(P, [ 24, 24, 44, 66, ex ], bands, [ E.pour, E.arcA, E.arcA, E.arcA ])
      let y = tr(P, [ pTop + 6.4, pTop + 2.4, 37.7, 19.4, ey ], bands, [ E.pour, E.arcB, E.arcB, E.arcB ])
      if (P > 1 && P < 2) y -= 2.2 * Math.sin(Math.PI * band(tBC, 0.28, 0.84, E.lin))
      const s = tr(P, [ 0.85, 0.85, 1, 0.56, es ], bands)
      const phoneO = phone ? tr(P, [ 1, 1, 1, 0, reviewed ? 1 : 0 ], [ null, null, [ 0.1, 0.4 ], [ 0.5, 0.8 ] ], E.lin) : 1
      this.place(this.el.title, x, y, s, tr(P, [ 0, 1, 1, 1, 1 ], bands, E.lin) * phoneO)
      this.roll(this.el.title)?.set(tr(P, [ 0, 0, 1, 1, 2 ], [ null, [ 0.3, 0.84 ], null, [ 0.15, 0.6 ] ], E.lin))
      this.css(this.el.title, "color", mixc(INK, CREAM, onInk(y + 2.4 * s)))
    }
    // The date and time: rise in on the invite, step up beside the deck, roll away for the record.
    {
      // the date goes after the words above it have made way
      const bands = [ null, null, [ 0.12, 0.6 ], null ]
      // up the left edge first (the time line has already gone right), then across the top
      const y = tr(P, [ 41.3, 41.3, 41.3, 5.4, 5.4 ], bands, [ E.lin, E.lin, E.lead ])
      const s = tr(P, [ 1, 1, 1, 0.55, 0.55 ], bands)
      this.place(this.el.date, tr(P, [ 4.4, 4.4, 4.4, 65.6, 65.6 ], bands, [ E.lin, E.lin, E.lag ]), y, s, 1)
      this.roll(this.el.date)?.set(tr(P, [ 0, 0, 1, 1, 2 ], [ null, [ 0.5, 1 ], null, [ 0, 0.3 ] ], E.lin))
      this.css(this.el.date, "color", mixc(INK, CREAM, onInk(y + 6 * s)))
    }
    {
      const bands = [ null, null, [ 0, 0.38 ], null ]
      const y = tr(P, [ 29.7, 29.7, 29.7, 14.6, 14.6 ], bands, E.arcB)
      this.place(this.el.time, tr(P, [ 5, 5, 5, 66.2, 66.2 ], bands, E.arcA), y, 1, phone ? 0 : 1)
      this.roll(this.el.time)?.set(tr(P, [ 0, 0, 1, 1, 2 ], [ null, [ 0.44, 0.94 ], null, [ 0, 0.3 ] ], E.lin))
      const c = onInk(y + 1.4)
      this.css(this.el.time, "color", mixc(INK, CREAM, c, lerp(1, 0.8, c)))
    }
    if (this.el.tag) {
      const w = this.roll(this.el.tag)?.lines[1]?.w / this.u || 14
      // its outline comes and goes with its words
      this.place(this.el.tag, 95 - w - 3.2, 29.1, 1, phone ? 0 : tr(P, [ 0, 0, 1, 0, 0 ], [ null, [ 0.5, 0.85 ], [ 0, 0.3 ] ], E.lin))
      this.roll(this.el.tag)?.set(tr(P, [ 0, 0, 1, 2, 2 ], [ null, [ 0.5, 1 ], [ 0, 0.34 ] ], E.lin))
    }
    // The category rolls into where the night is, then where the record is.
    {
      const bands = [ [ 0.38, 0.88 ], [ 0.32, 0.86 ], [ 0.04, 0.46 ], [ 0.14, 0.46 ] ]
      const ex = reviewed ? 7 : (verdict && cfg.slide_in_record ? 15.6 : 5), ey = reviewed ? 31.2 : 14.6, es = reviewed ? 1.1 : 0.78
      const x = tr(P, [ 24, 24, 44, 66, ex ], bands, [ E.pour, E.arcA, E.arcA, E.lag ])
      let y = tr(P, [ pTop + 10.9, pTop + 6.9, 42.9, 23.4, ey ], bands, [ E.pour, E.arcB, E.arcB, E.lead ])
      if (P > 1 && P < 2) y -= 1.6 * Math.sin(Math.PI * band(tBC, 0.32, 0.86, E.lin))
      const s = tr(P, [ 0.96, 0.96, 1, 0.82, es ], bands)
      this.place(this.el.meta, x, y, s, phone ? 0 : tr(P, [ 0, 1, 1, 1, 1 ], bands, E.lin))
      this.roll(this.el.meta)?.set(tr(P, [ 0, 0, 1, 1, 2 ], [ null, [ 0.4, 0.95 ], null, [ 0.12, 0.42 ] ], E.lin))
      const cr = onInk(y + 1.6 * s)
      this.css(this.el.meta, "color", P < 2 ? mixc(MUTE, INK, tr(P, [ 0, 0, 1, 1, 1 ], [ null, [ 0.3, 0.7 ] ], E.lin)) : mixc(INK, CREAM, cr, lerp(1, 0.72, cr)))
    }
    const goingX = 44 + 5.6 * gI + 2.4
    this.place(this.el.going, goingX, 48.7, 1, phone ? 0 : 1)
    this.roll(this.el.going)?.set(tr(P, [ 0, 0, 1, 2, 2 ], [ null, [ 0.66, 1 ], [ 0, 0.34 ] ], E.lin))

    // The glasses: guests on the invite, seats at the table, the night's pours.
    // Only the invite's glasses sit at the table (a real night never shows
    // more people than said yes); a record's pours beyond them rise straight
    // into the record.
    const fill = (k) => band(f, (k * 0.88) / Math.max(1, T), (k * 0.88) / Math.max(1, T) + 0.34, E.pour)
    for (let k = 0; k < S; k++) {
      const g = this.el.glasses[k]
      if (!g) continue
      const seated = k < T, kept = k < gR
      const inA = 0.54 + [ 0, 0.06, 0.11, 0.15 ][k]
      // To the record the rightmost glass leaves first, so none is still at
      // the right when the card rises there.
      const out = seated ? T - 1 - k : 0
      const bands = [ null, [ inA, inA + 0.3 ], [ 0.2 + 0.05 * k, 0.78 + 0.05 * k ], [ 0.02 + 0.08 * out, 0.42 + 0.08 * out ] ]
      const cx = 44 + 5.6 * k, cy = 46.1, sx = seat(k) - 3
      // In the record: a row's glass, the review's score glass, or it sinks away.
      let ex = sx, ey = 50, es = 0.8, eo = 0
      if (rowsShown && kept) { ex = 5; ey = rowY(k, "glass"); es = 0.6; eo = 1 } else if (reviewed && k === 0) { ex = 57.2; ey = 5.2; es = 0.46; eo = P >= 4 ? 0 : 1 }
      let x, y, s, o, lift = 0
      if (seated) {
        // to the record: a bowed path up and left into its row, the rightmost first
        x = tr(P, [ cx, cx, cx, sx, ex ], bands, [ E.lin, E.pour, E.arcA, E.arcA ])
        y = tr(P, [ cy + 4, cy + 4, cy, 44.5, ey ], bands, [ E.lin, E.pour, E.arcB, E.arcB ])
        lift = P > 3 && eo ? 3 * Math.sin(Math.PI * band(tDE, bands[3][0], bands[3][1], E.lin)) : 0
        y -= lift
        s = tr(P, [ 0.7, 0.7, 0.7, 0.8, es ], bands)
        // a glass with no place in the record sinks away first, before the card rises
        o = tr(P, [ 0, 0, 1, 1, eo ], [ null, bands[1], bands[2], eo ? bands[3] : [ 0, 0.2 ] ], E.lin)
      } else {
        // no seat at the table: it rises into its place in the record
        const rise = P >= 4 ? 1 : P > 3 ? band(tDE, 0.3 + 0.05 * k, 0.62 + 0.05 * k, E.pour) : 0
        x = ex; y = ey + 5 * (1 - rise); s = es; o = eo * rise
      }
      this.place(g, x, y, s, o)
      // A pour at the table; in the record, the room's score (glass level = mean / 5).
      const poured = seated ? fill(k) : 0
      const want = rowsShown && kept ? cfg.levels[k] : (reviewed && k === 0 ? cfg.levels[0] : poured)
      let lv = 0
      if (P > 2 && P < 3) lv = poured * band(tCD, 0.3, 0.85, E.lin)
      else if (P === 3) lv = poured
      else if (P > 3) lv = seated ? lerp(poured, want, band(tDE, 0, 0.5)) : want
      this.glassDrawings[k].level(lv)
      const tone = onInk(y + 6 * s)
      this.glassDrawings[k].tone(reviewed && k === 0 && P > 3 ? lerp(tone, 0, band(tDE, 0.5, 0.8, E.lin)) : tone)

      const label = this.el.labels[k]
      if (label) {
        const lr = this.roll(label)
        const ls = tr(P, [ 0.7, 0.7, 0.7, 0.7, 1 ], [ null, null, null, bands[3] ])
        const w1 = ((lr?.lines[1]?.w || 0) / this.u) * ls
        const cxl = seat(k)
        const atRow = rowsShown && kept
        // a label with no seat waits at its row, where it rolls in
        const lx = seated ? tr(P, [ cxl - w1 / 2, cxl - w1 / 2, cxl - w1 / 2, cxl - w1 / 2, atRow ? 11.4 : cxl - w1 / 2 ], [ null, null, null, bands[3] ], E.arcA) : 11.4
        const ly = seated ? tr(P, [ 53.1, 53.1, 53.1, 53.1, atRow ? rowY(k, "label") : 56 ], [ null, null, null, bands[3] ], E.arcB) - lift : rowY(k, "label")
        const phoneO = phone ? tr(P, [ 0, 0, 0, 0, 1 ], [ null, null, null, [ 0.5, 0.8 ] ], E.lin) : 1
        this.place(label, lx, ly, ls, phoneO)
        lr?.set(tr(P, [ 0, 0, 0, 1, 2 ], [ null, null, [ 0.6 + 0.05 * k, 0.95 + 0.05 * k ], atRow ? [ 0.3 + 0.05 * k, 0.6 + 0.05 * k ] : [ 0, 0.22 ] ], E.lin))
        this.css(label, "color", mixc(INK, CREAM, tone))
      }
      const score = this.el.scores[k]
      if (score) {
        const sr = this.roll(score)
        this.place(score, (wheelCard ? 51 : 95) - (sr?.lines[1]?.w || 0) / this.u, rowY(k, "score"))
        sr?.set(tr(P, [ 0, 0, 0, 0, 1 ], [ null, null, null, [ 0.44 + 0.08 * k, 0.66 + 0.08 * k ] ], E.lin))
      }
      const rule = this.el.vlines[k]
      if (rule) {
        this.css(rule, "width", `${wheelCard ? 46 : 90}cqw`)
        const vs = tr(P, [ 0, 0, 0, 0, 1 ], [ null, null, null, [ 0.3 + 0.06 * k, 0.62 + 0.06 * k ] ], E.out)
        this.place(rule, 5, rowY(k), 1, vs > 0 ? 1 : 0, ` scaleX(${vs.toFixed(4)})`)
      }
      // Who reviewed it, under the drink's name (rows of reviews only).
      const by = this.el.bys[k]
      if (by) {
        this.place(by, 11.4, rowY(k, "by"))
        this.roll(by)?.set(tr(P, [ 0, 0, 0, 0, 1 ], [ null, null, null, [ 0.4 + 0.06 * k, 0.7 + 0.06 * k ] ], E.lin))
      }
    }

    // The record: its heading rolls in, the card rises from below the frame,
    // and once the record has arrived its wheel draws on its own clock (this.w).
    this.roll(this.el.heading)?.set(tr(P, [ 0, 0, 0, 0, 1 ], [ null, null, null, [ 0.04, 0.4 ] ], E.lin))
    this.place(this.el.heading, reviewed ? 7 : 5, reviewed ? 5.4 : 4.4)
    if (this.el.card) {
      // early, so the frame is anchored while the glasses are in the air
      const pc = P >= 4 ? 1 : P > 3 ? band(tDE, CARD_RISE[0], CARD_RISE[1]) : 0
      const cx = carded ? 54.5 : 56, cy = carded ? 3.4 : 4
      this.place(this.el.card, cx, cy + 54 * (1 - pc), 1, pc > 0 ? 1 : 0)
      // the review's own score glass shows once glass 0 has landed on it
      // (rows of reviews: their glasses land on the rows, so it is simply there)
      this.css(this.el.cardScore?.querySelector("svg"), "visibility", P >= 4 || listed ? "visible" : "hidden")
    }
    const wt = this.w
    for (const w of this.wedges) {
      const g = E.out(clamp01((wt - w.at) / WHEEL_GROW))
      const sc = lerp(w.from, 1, g)
      if (w.s !== sc) { w.el.style.transform = `scale(${sc.toFixed(4)})`; w.s = sc }
      const fc = E.out(clamp01((wt - w.at - WHEEL_TINT_LAG) / WHEEL_TINT))
      if (w.c !== fc) { w.el.style.fill = fc >= 1 ? "" : mixOk(SOFT, SAGE, fc); w.c = fc }
    }
    const lo = this.wedges.length ? clamp01((wt - this.labelsAt) / WHEEL_LABELS) : (P >= 4 ? 1 : P > 3 ? band(tDE, 0.86, 1, E.lin) : 0)
    for (const t of this.wheelLabels) this.css(t, "opacity", lo.toFixed(3))
    if (this.el.review) {
      const pr = P >= 4 ? 1 : P > 3 ? band(tDE, 0.3, 0.72, E.pour) : 0
      this.place(this.el.review, listed ? 5 : 7, (listed ? rowY(cfg.record_glasses) + 2.4 : 36.4) + 3 * (1 - pr), 1, phone ? 0 : pr)
    }

    // The frame's caption rolls with the step.
    this.capL?.set(tr(P, [ 0, 1, 2, 3, 4 ], [ [ 0.3, 0.8 ], [ 0.3, 0.8 ], [ 0.3, 0.8 ], [ 0.3, 0.8 ] ], E.lin))
    if (this.capR) {
      // "Glass k of T" while the glasses fill (states 2 .. T+1); "" is 1 and T+2.
      let g = 2
      for (let k = 1; k < T; k++) g += band(f, (k * 0.88) / T - 0.03, (k * 0.88) / T + 0.05, E.lin)
      if (P < 1) this.capR.set(tr(P, [ 0, 1, 1, 1, 1 ], [ [ 0.3, 0.8 ] ], E.lin))
      else if (P < 2) this.capR.set(1)
      else if (P < 3) this.capR.between(1, Math.round(g), band(tCD, 0.5, 0.9, E.lin))
      else if (P === 3) this.capR.set(g)
      else this.capR.between(Math.round(g), T + 2, band(tDE, 0.1, 0.5, E.lin))
    }
  }
}
