import { Controller } from "@hotwired/stimulus"

// Concept 4: "The Theatre of the Pour" (/concepts/4, home/concept_4).
//
// The page arrives as five stacked beats of real HTML (that is the page
// without JS, in print, and in a window too short to hold a beat). This
// controller goes "live" when every beat fits the screen: the beats share
// one pinned screen, the scroll picks the beat, and two kinds of object
// travel between the beats' slots ([data-slot]), wherever each beat's own
// layout puts them:
//   - the deck screen (one), on every [data-slot="deck"];
//   - the glasses, on [data-slot="glass"][data-k].
// A slot keeps its own static picture; while an object rests on it the slot
// is .is-held and its picture hidden, so anything that fails leaves the
// static picture showing.
//
// All content is the server's: names, numbers and words live in the markup
// (elements marked [data-for-deck] follow the picked deck). The config value
// carries only ids, counts and glass levels (ConceptFourHelper).
//
// Frames run only while something moves (a glass travelling, filling or
// settling) and never while the theatre is off screen. Under reduced motion
// every beat lands at rest: no travel, no fill, no slosh.

const BEATS = 5
const DWELL = 4.6      // bands of scroll the screen stays pinned (the last beat dwells .6)
const SCREEN_W = 640   // the deck screen's layout width (CSS), scaled to its slot
const GLASS_H = 80     // a glass object's layout height (CSS)
const SPAN = 24        // shared/_glass: the level's travel in drawing units
const TRAVEL = 0.8     // seconds a glass takes between slots
const STEP = 1000 / 60 // the slosh spring's fixed step, ms
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v))
const easeOut = (t) => 1 - Math.pow(1 - clamp(t), 3)

export default class extends Controller {
  static targets = [ "theatre", "stage", "beat", "rail", "screen", "reel", "glass", "pick", "flip", "count", "rank", "wheel" ]
  static values = { config: Object }

  connect() {
    this.motion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.beat = 0
    this.live = false
    this.visible = true
    this.deck = String(this.configValue.deck ?? "")
    this.slideAt = {}
    this.timers = []
    this.raf = null
    this.last = 0
    this.acc = 0
    this.glasses = this.glassTargets.map((el, k) => ({
      el, k, body: el.querySelector("svg g > path"),
      x: 0, y: 0, sc: 1, op: 0, rot: 0, lvl: 1, goal: 1, slosh: 0, vel: 0, moving: false
    }))

    this.onScroll = this.onScroll.bind(this)
    this.onResize = this.onResize.bind(this)
    this.onFocus = this.onFocus.bind(this)
    this.tick = this.tick.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onResize, { passive: true })
    this.motion.addEventListener("change", this.onResize)
    this.stageTarget.addEventListener("focusin", this.onFocus)
    this.watcher = new IntersectionObserver(([ entry ]) => this.seen(entry.isIntersecting))
    this.watcher.observe(this.theatreTarget)
    if (document.fonts?.ready) document.fonts.ready.then(() => { if (this.connected) this.refresh() })

    this.connected = true
    this.syncFlip()
    this.refresh()
    if (this.live && window.location.hash === "#how-it-works") this.go(1, true)
  }

  disconnect() {
    this.connected = false
    this.clearTimers()
    if (this.raf) cancelAnimationFrame(this.raf)
    this.raf = null
    clearTimeout(this.resizeTimer)
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onResize)
    this.motion.removeEventListener("change", this.onResize)
    this.stageTarget.removeEventListener("focusin", this.onFocus)
    this.watcher.disconnect()
    this.goStatic()
  }

  get reduced() { return this.motion.matches }

  // ---- Live or static ----------------------------------------------------

  // Live only when every beat's content fits the pinned screen.
  refresh() {
    try {
      this.element.classList.add("is-live")
      const fits = this.beatTargets.every((beat) => beat.scrollHeight <= beat.clientHeight + 1 && beat.scrollWidth <= beat.clientWidth + 1)
      if (!fits) { this.goStatic(); return }
      this.live = true
      this.pickRects = this.measurePicks()
      this.enter(this.beatFromScroll(), true)
    } catch (error) {
      console.error("Concept 4: showing the static page", error)
      this.goStatic()
    }
  }

  goStatic() {
    this.live = false
    this.clearTimers()
    this.element.classList.remove("is-live")
    this.element.querySelectorAll(".c4-slot.is-held").forEach((slot) => slot.classList.remove("is-held"))
  }

  seen(visible) {
    this.visible = visible
    if (!this.live) return
    if (visible) this.enter(this.beatFromScroll(), true)
    else if (this.raf) { cancelAnimationFrame(this.raf); this.raf = null }
  }

  onResize() {
    clearTimeout(this.resizeTimer)
    this.resizeTimer = setTimeout(() => { if (this.connected) this.refresh() }, 120)
  }

  // ---- Which beat --------------------------------------------------------

  band() {
    return (this.theatreTarget.offsetHeight - this.stageTarget.offsetHeight) / DWELL
  }

  beatFromScroll() {
    const top = this.theatreTarget.getBoundingClientRect().top
    return clamp(Math.round(-top / this.band()), 0, BEATS - 1)
  }

  onScroll() {
    if (!this.live || !this.visible) return
    const beat = this.beatFromScroll()
    if (beat !== this.beat) this.enter(beat, false)
  }

  // Keyboard: focus moving into another beat brings that beat on.
  onFocus(event) {
    if (!this.live) return
    const beat = this.beatTargets.findIndex((el) => el.contains(event.target))
    if (beat >= 0 && beat !== this.beat) this.go(beat, true)
  }

  // The rail and "See how it works".
  jump(event) {
    event.preventDefault()
    this.go(Number(event.currentTarget.dataset.beat), false)
  }

  go(beat, instant) {
    if (!this.live) {
      this.beatTargets[beat]?.scrollIntoView({ behavior: instant || this.reduced ? "auto" : "smooth" })
      return
    }
    const top = this.theatreTarget.getBoundingClientRect().top + window.scrollY + beat * this.band()
    window.scrollTo({ top, behavior: instant || this.reduced ? "instant" : "smooth" })
    if (instant) this.enter(beat, true)
  }

  enter(beat, instant) {
    instant = instant || this.reduced
    this.beat = beat
    this.clearTimers()
    this.stageTarget.dataset.beat = String(beat)
    this.beatTargets.forEach((el, i) => el.classList.toggle("is-active", i === beat))
    this.railTargets.forEach((el, i) => { if (i === beat) el.setAttribute("aria-current", "step"); else el.removeAttribute("aria-current") })
    this.placeScreen(instant)
    this.placeGlasses(instant)
    this.kick()
  }

  // ---- Slots -------------------------------------------------------------

  slots(beat, kind) {
    return [ ...this.beatTargets[beat].querySelectorAll(`[data-slot="${kind}"]`) ].filter((el) => el.offsetParent !== null)
  }

  // A slot's box in the stage's own coordinates.
  box(el) {
    const stage = this.stageTarget.getBoundingClientRect()
    const r = el.getBoundingClientRect()
    return { x: r.left - stage.left, y: r.top - stage.top, w: r.width, h: r.height }
  }

  release(beat, kind) {
    this.beatTargets[beat].querySelectorAll(`[data-slot="${kind}"].is-held`).forEach((slot) => slot.classList.remove("is-held"))
  }

  // Change an element with no transition, then let transitions run again.
  instantly(el, change) {
    el.style.transition = "none"
    change()
    void el.offsetWidth
    el.style.transition = ""
  }

  // ---- The deck screen ---------------------------------------------------

  pickedCard() {
    return this.pickTargets.find((card) => card.querySelector("input")?.checked)
  }

  deckSlot(beat) {
    if (beat === 1) return this.pickedCard()?.querySelector('[data-slot="deck"]') || null
    return this.slots(beat, "deck").find((slot) => !slot.dataset.onlyDeck || slot.dataset.onlyDeck === this.deck) || null
  }

  setScreen(slot) {
    const b = this.box(slot)
    const scale = b.w / SCREEN_W
    const radius = parseFloat(getComputedStyle(slot).borderTopLeftRadius) || 0
    this.screenTarget.style.transform = `translate3d(${b.x.toFixed(2)}px, ${b.y.toFixed(2)}px, 0) scale(${scale.toFixed(4)})`
    this.screenTarget.style.borderRadius = `${(radius / scale).toFixed(2)}px`
  }

  placeScreen(instant) {
    if (!this.hasScreenTarget) return
    const screen = this.screenTarget
    this.unpark()
    this.release(this.beat, "deck")
    const slot = this.deckSlot(this.beat)
    if (!slot) { screen.classList.add("is-out"); return }
    slot.classList.add("is-held")
    if (instant || screen.classList.contains("is-out")) this.instantly(screen, () => this.setScreen(slot))
    else this.setScreen(slot)
    screen.classList.remove("is-out")
    // On the pick beat the screen hands over to the picked card's own cover
    // once it has landed, so the cards are whole when they trade places.
    // (so the screen shows the cover the card shows: its first slide).
    if (this.beat === 1) {
      if (this.slideAt[this.deck]) this.flip(-this.slideAt[this.deck])
      this.after(instant ? 0 : 820, () => this.park())
    }
  }

  park() {
    if (this.beat !== 1 || !this.hasScreenTarget) return
    this.pickTargets.forEach((card) => card.querySelector('[data-slot="deck"]')?.classList.remove("is-held"))
    this.screenTarget.classList.add("is-parked")
    this.parked = true
  }

  // Back on the picked card's cover, shown, ready to travel.
  unpark() {
    if (!this.parked) return
    this.parked = false
    this.pickTargets.forEach((card) => card.getAnimations().forEach((animation) => animation.finish()))
    const slot = this.pickedCard()?.querySelector('[data-slot="deck"]')
    this.instantly(this.screenTarget, () => {
      if (slot) { slot.classList.add("is-held"); this.setScreen(slot) }
      this.screenTarget.classList.remove("is-parked")
    })
  }

  // ---- Picking a deck ----------------------------------------------------

  measurePicks() {
    return this.pickTargets.map((card) => card.getBoundingClientRect())
  }

  pick(event) {
    this.deck = String(event.target.value)
    this.element.querySelectorAll("[data-for-deck]").forEach((el) => { el.hidden = el.dataset.forDeck !== this.deck })
    this.syncFlip()
    if (!this.live) return
    if (this.beat === 1) { this.clearTimers(); this.park() }
    // The cards trade places (FLIP): from where they were to where the new layout puts them.
    this.pickTargets.forEach((card) => card.getAnimations().forEach((animation) => animation.finish()))
    const first = this.pickRects
    const last = this.measurePicks()
    this.pickRects = last
    if (!first || this.reduced) return
    this.pickTargets.forEach((card, i) => {
      const a = first[i], z = last[i]
      if (!a || !z || !z.width) return
      const dx = a.left - z.left, dy = a.top - z.top, scale = a.width / z.width
      if (Math.abs(dx) < 1 && Math.abs(dy) < 1 && Math.abs(scale - 1) < 0.01) return
      card.animate(
        [ { transformOrigin: "0 0", transform: `translate(${dx}px, ${dy}px) scale(${scale})` }, { transformOrigin: "0 0", transform: "none" } ],
        { duration: 520, easing: "cubic-bezier(0.23, 1, 0.32, 1)" }
      )
    })
  }

  // ---- The picked deck's slides ------------------------------------------

  reel() {
    return this.reelTargets.find((el) => el.dataset.forDeck === this.deck)
  }

  syncFlip() {
    const count = this.configValue.decks?.[this.deck]?.slides || 0
    const at = this.slideAt[this.deck] || 0
    this.flipTargets.forEach((el) => { el.hidden = count < 2 })
    this.countTargets.forEach((el) => { el.textContent = count < 2 ? "" : `${at + 1} / ${count}` })
  }

  nextSlide() { this.flip(1) }
  previousSlide() { this.flip(-1) }

  flip(by) {
    const reel = this.reel()
    if (!reel || reel.children.length < 2) return
    const count = reel.children.length
    const at = ((this.slideAt[this.deck] || 0) + by + count) % count
    this.slideAt[this.deck] = at
    ;[ ...reel.children ].forEach((slide, i) => slide.classList.toggle("is-on", i === at))
    this.syncFlip()
  }

  // ---- The verdict's wheel: a pour's row lights the wedges it feeds --------

  lightWedges(event) {
    if (!this.hasWheelTarget) return
    const k = event.currentTarget.dataset.k
    this.wheelTarget.querySelectorAll("[data-pour]").forEach((wedge) => wedge.classList.toggle("is-lit", wedge.dataset.pour === k))
  }

  dimWedges() {
    if (!this.hasWheelTarget) return
    this.wheelTarget.querySelectorAll(".is-lit").forEach((wedge) => wedge.classList.remove("is-lit"))
  }

  // ---- The glasses -------------------------------------------------------

  placeGlasses(instant) {
    const beat = this.beat
    this.release(beat, "glass")
    const slots = this.slots(beat, "glass")
    const levels = this.configValue.record?.levels || []
    const now = performance.now() / 1000
    this.glasses.forEach((g) => {
      const slot = slots.find((el) => Number(el.dataset.k) === g.k)
      let to = { x: g.x, y: g.y, sc: g.sc, op: 0 }
      if (slot) {
        slot.classList.add("is-held")
        const b = this.box(slot)
        to = { x: b.x + b.w / 2, y: b.y + b.h / 2, sc: b.h / GLASS_H, op: 1 }
        g.el.classList.toggle("is-cream", beat >= 3)
        g.cream = beat >= 3
      }
      // Full on the invite, poured one after another at the table, the room's score on the record.
      const goal = beat === 4 ? clamp(levels[g.k] ?? 1) : 1
      if (instant) {
        Object.assign(g, to, { rot: 0, lvl: goal, goal, slosh: 0, vel: 0, moving: false })
        return
      }
      if (g.op < 0.05 && slot) Object.assign(g, { x: to.x, y: to.y + 26, sc: to.sc }) // arrives in place, rising
      g.from = { x: g.x, y: g.y, sc: g.sc, op: g.op }
      g.to = to
      g.ctrl = { x: (g.x + to.x) / 2, y: Math.min(g.y, to.y) - (slot && g.op > 0.05 ? 48 : 0) }
      g.t0 = now + g.k * 0.06
      g.moving = true
      if (beat === 3 && slot) {
        g.goal = 0
        this.after(520 + g.k * 380, () => { g.goal = 1; g.vel += g.k % 2 ? -3.6 : 3.6; this.kick() })
      } else {
        g.goal = goal
      }
    })
    if (instant) this.glasses.forEach((g) => this.draw(g))
  }

  kick() {
    if (this.raf || !this.live || !this.visible || this.reduced) return
    this.last = 0
    this.raf = requestAnimationFrame(this.tick)
  }

  tick(now) {
    this.raf = null
    const dt = this.last ? Math.min(now - this.last, 50) : STEP
    this.last = now
    this.acc += dt
    const steps = Math.floor(this.acc / STEP)
    this.acc -= steps * STEP
    const t = now / 1000
    let busy = false
    this.glasses.forEach((g) => {
      if (g.moving) {
        busy = true
        const raw = (t - g.t0) / TRAVEL
        if (raw >= 1) {
          Object.assign(g, g.to, { rot: 0, moving: false })
          if (g.op > 0) g.vel += g.k % 2 ? -3.2 : 3.2 // it lands, the liquid rocks
        } else if (raw > 0) {
          const u = easeOut(raw), v = 1 - u
          g.x = v * v * g.from.x + 2 * v * u * g.ctrl.x + u * u * g.to.x
          g.y = v * v * g.from.y + 2 * v * u * g.ctrl.y + u * u * g.to.y
          g.sc = g.from.sc + (g.to.sc - g.from.sc) * u
          g.op = g.from.op + (g.to.op - g.from.op) * clamp(raw * 1.6)
          g.rot = Math.sin(u * Math.PI) * clamp((g.to.x - g.from.x) * 0.02, -7, 7)
        }
      }
      for (let i = 0; i < steps; i++) {
        g.lvl += (g.goal - g.lvl) * 0.085
        g.vel += -g.slosh * 0.14
        g.vel *= 0.87
        g.slosh += g.vel * 0.17
      }
      if (Math.abs(g.goal - g.lvl) > 0.003) busy = true
      else g.lvl = g.goal
      if (Math.abs(g.slosh) > 0.03 || Math.abs(g.vel) > 0.03) busy = true
      else { g.slosh = 0; g.vel = 0 }
      this.draw(g)
    })
    if (busy && this.live && this.visible) this.raf = requestAnimationFrame(this.tick)
  }

  // A glass where it is, as full as it is. At rest the surface is exactly
  // shared/_glass's own, so a glass and its slot's static picture agree.
  draw(g) {
    g.el.style.opacity = g.op.toFixed(3)
    g.el.style.transform = `translate3d(${(g.x - 30).toFixed(2)}px, ${(g.y - 40).toFixed(2)}px, 0) scale(${g.sc.toFixed(4)}) rotate(${g.rot.toFixed(2)}deg)`
    if (!g.body) return
    if (g.lvl < 0.02) { g.body.setAttribute("d", ""); return }
    const y = 58.5 - clamp(g.lvl) * SPAN
    const tilt = clamp(g.slosh, -6, 6)
    const f = (d, lean) => (y + d + tilt * lean).toFixed(2)
    g.body.setAttribute("d", `M8 ${f(1.2, -1)} C18 ${f(-2.2, -0.6)} 26 ${f(3.2, -0.2)} 36 ${f(0.6, 0.3)} C42 ${f(-1, 0.5)} 48 ${f(-1.6, 0.8)} 52 ${f(-0.6, 1)} L52 70 L8 70 Z`)
    g.body.setAttribute("fill", g.cream ? "#ff6d00" : "#e65c00")
  }

  // ---- Timers ------------------------------------------------------------

  after(ms, fn) {
    this.timers.push(setTimeout(fn, ms))
  }

  clearTimers() {
    this.timers.forEach((id) => clearTimeout(id))
    this.timers = []
  }
}
