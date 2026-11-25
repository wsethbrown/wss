import { Controller } from "@hotwired/stimulus"

// Concept 2 ("The Tactile Tasting Table") Stimulus controller:
// - Physical flickable 3D hero deck stack (click or drag to cycle)
// - Vertical-to-horizontal sticky Tabletop Rail with drawing orange Pour Thread
// - Live category filter on Station 1 (Deck Shelf)
// - Interactive RSVP toggle on Station 2 (Tear-Off Tasting Ticket)
// - Overhead 4-Pour Tasting Mat on Station 3 (click coasters to pour & inspect)
// - Interactive 8-Axis Palate Sculptor on Station 4 (click wedges or buttons to rate)

const MAT_POURS = [
  { nose: "Vanilla bean, sweet corn, light citrus zest", palate: "Honeyed caramel, soft toasted oak, mellow warmth", finish: "Clean, gently sweet with a hint of mint" },
  { nose: "Baked apple, brown sugar, French oak spice", palate: "Creamy butterscotch, toasted stave cinnamon", finish: "Medium-long, velvety baking spice" },
  { nose: "Roasted peanuts, wildflower honey, clove", palate: "Full-bodied caramel, dry rye spice, charred wood", finish: "Warm, structured, lingering oak grip" },
  { nose: "Burnt orange peel, dark cherry, cedar", palate: "Bold cinnamon heat, dense toffee, rich barrel char", finish: "Long, electric spice that anchors the night" }
]

export default class extends Controller {
  static targets = [
    "card", "stackCount",
    "railWrap", "railPin", "track", "stepBtn", "threadGlass",
    "fchip", "shelfItem",
    "rsvpPill", "rsvpStatus",
    "coaster", "matNose", "matPalate", "matFinish",
    "axisBtn", "sculptWedge", "sculptScore", "sculptGlass"
  ]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.order = this.cardTargets.map((_, i) => i)
    this.flicking = false
    this.axisLevels = [2, 3, 2, 1, 1, 2, 0, 0]

    this.onScroll = this.onScroll.bind(this)
    this.tick = this.tick.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })

    this.layoutStack()
    this.selectCoasterIndex(0)
    this.renderSculptor()
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  // --- Hero Flickable 3D Stack ---
  flickCard() {
    if (this.flicking || this.cardTargets.length < 2) return
    this.flicking = true
    const frontIdx = this.order[0]
    const frontEl = this.cardTargets[frontIdx]
    frontEl.classList.add("is-flicking")

    setTimeout(() => {
      frontEl.classList.remove("is-flicking")
      this.order.push(this.order.shift())
      this.layoutStack()
      this.flicking = false
    }, this.reduced ? 40 : 280)
  }

  layoutStack() {
    this.order.forEach((cardIdx, pos) => {
      const el = this.cardTargets[cardIdx]
      if (el) el.dataset.pos = String(pos)
    })
    if (this.hasStackCountTarget) {
      const current = this.order[0] + 1
      this.stackCountTarget.textContent = `0${current} / 0${this.cardTargets.length}`
    }
  }

  // --- Vertical-to-Horizontal Tabletop Rail ---
  onScroll() {
    if (!this.raf) this.raf = requestAnimationFrame(this.tick)
  }

  tick() {
    this.raf = null
    if (!this.hasRailWrapTarget || !this.hasTrackTarget) return
    if (window.innerWidth < 900) return

    const rect = this.railWrapTarget.getBoundingClientRect()
    const scrollable = Math.max(1, this.railWrapTarget.offsetHeight - window.innerHeight)
    const p = Math.min(1, Math.max(0, -rect.top / scrollable))

    const maxShift = Math.max(0, this.trackTarget.scrollWidth - window.innerWidth)
    const x = -(p * maxShift)

    this.trackTarget.style.setProperty("--rail-x", `${x.toFixed(1)}px`)
    this.railPinTarget.style.setProperty("--rail-p", p.toFixed(4))

    if (this.hasThreadGlassTarget) {
      const drop = ((1 - p) * 28).toFixed(2)
      this.threadGlassTarget.style.setProperty("--c2-glass-drop", `${drop}px`)
    }

    const activeStep = Math.min(3, Math.floor(p * 3.99))
    this.stepBtnTargets.forEach((b, i) => b.classList.toggle("is-active", i === activeStep))
  }

  jumpStation(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (!this.hasRailWrapTarget) return
    const top = this.railWrapTarget.getBoundingClientRect().top + window.scrollY
    const scrollable = Math.max(1, this.railWrapTarget.offsetHeight - window.innerHeight)
    const targetY = top + (idx / 3) * scrollable
    window.scrollTo({ top: targetY, behavior: this.reduced ? "auto" : "smooth" })
  }

  // --- Station 1: Live Shelf Filter ---
  filterShelf(event) {
    const cat = event.currentTarget.dataset.cat
    this.fchipTargets.forEach((c) => c.classList.toggle("is-active", c.dataset.cat === cat))
    this.shelfItemTargets.forEach((item) => {
      const match = cat === "all" || item.dataset.cat === cat
      item.hidden = !match
    })
  }

  // --- Station 2: Interactive Ticket RSVP ---
  setRsvp(event) {
    const status = event.currentTarget.dataset.status
    this.rsvpPillTargets.forEach((b) => {
      b.classList.remove("is-yes", "is-maybe", "is-no")
      if (b === event.currentTarget) b.classList.add(`is-${status}`)
    })
    if (this.hasRsvpStatusTarget) {
      const msg = { yes: "Seat reserved · 6 glasses set for Friday", maybe: "Half glass poured · we'll save you a spot", no: "Next month's pour has your name on it" }
      this.rsvpStatusTarget.textContent = msg[status] || ""
    }
  }

  // --- Station 3: Overhead 4-Pour Tasting Mat ---
  selectCoaster(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    this.selectCoasterIndex(idx)
  }

  selectCoasterIndex(idx) {
    const data = MAT_POURS[idx] || MAT_POURS[0]
    this.coasterTargets.forEach((c, i) => c.classList.toggle("is-active", i === idx))
    if (this.hasMatNoseTarget) this.matNoseTarget.textContent = data.nose
    if (this.hasMatPalateTarget) this.matPalateTarget.textContent = data.palate
    if (this.hasMatFinishTarget) this.matFinishTarget.textContent = data.finish
  }

  // --- Station 4: Interactive Palate Sculptor ---
  cycleAxis(event) {
    const idx = parseInt(event.currentTarget.dataset.axis, 10)
    this.axisLevels[idx] = (this.axisLevels[idx] + 1) % 4
    this.renderSculptor()
  }

  renderSculptor() {
    let sum = 0
    this.axisLevels.forEach((lvl, i) => {
      sum += lvl
      const btn = this.axisBtnTargets[i]
      if (btn) btn.dataset.level = String(lvl)

      const wedge = this.sculptWedgeTargets[i]
      if (wedge) {
        const scale = (0.24 + (lvl / 3) * 0.76).toFixed(3)
        wedge.style.transform = `scale(${scale})`
        wedge.style.opacity = lvl === 0 ? "0.14" : (0.45 + (lvl / 3) * 0.55).toFixed(2)
        wedge.setAttribute("fill", lvl === 3 ? "#ff6d00" : (lvl === 2 ? "#16332a" : "#8fa397"))
      }
    })

    // Derive a live tasting score (3.0 - 5.0) from palate richness
    const score = Math.min(5, Math.max(2.5, 3.0 + (sum / 18) * 1.9))
    if (this.hasSculptScoreTarget) this.sculptScoreTarget.textContent = score.toFixed(2)
    if (this.hasSculptGlassTarget) {
      const drop = ((1 - score / 5) * 24).toFixed(2)
      this.sculptGlassTarget.querySelectorAll("g > path").forEach((p) => {
        p.style.transform = `translateY(${drop}px)`
      })
    }
  }
}
