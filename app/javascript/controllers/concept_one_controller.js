import { Controller } from "@hotwired/stimulus"

// Concept 1 ("The Full-Stage Projection") Stimulus controller:
// - Scroll-reactive hero cinema tilt
// - Interactive 4-slide hero deck player
// - Sticky 4-act theatre (Pick -> Gather -> Pour -> Record) synced with
//   the live pouring Glencairn glass in the chapter dock
// - Interactive deck fan selection that carries into Act 2 & Act 3
// - Live RSVP pour toggle in Act 2
// - Interactive 4-pour tasting flight in Act 3
// - Live morphing 8-axis SVG Palate Wheel in Act 4
// - Segmented membership switcher

const POUR_DATA = [
  {
    num: "Pour 01 · Low Proof Opener",
    bottle: "Buffalo Trace",
    proof: "90 proof",
    age: "NAS · ~8 yrs",
    score: "4.1",
    level: 0.82,
    note: "Sweet vanilla bean, brown sugar, and bright orange peel — sets the baseline for the flight.",
    wheel: [0.85, 0.55, 0.35, 0.7, 0.15, 0.5, 0.45, 0.1]
  },
  {
    num: "Pour 02 · Wheated Mash Bill",
    bottle: "Maker's Mark 46",
    proof: "94 proof",
    age: "French oak staves",
    score: "4.25",
    level: 0.85,
    note: "Soft caramel and baked apple wrapped in toasted French oak spice with a velvet finish.",
    wheel: [0.92, 0.8, 0.48, 0.62, 0.2, 0.42, 0.35, 0.1]
  },
  {
    num: "Pour 03 · Bottled-in-Bond",
    bottle: "Heaven Hill 7 Year BiB",
    proof: "100 proof",
    age: "7 years · Single season",
    score: "4.4",
    level: 0.88,
    note: "Roasted peanut brittle, dark honey, and warm rye-led baking spice with real backbone.",
    wheel: [0.76, 0.85, 0.72, 0.45, 0.25, 0.65, 0.25, 0.12]
  },
  {
    num: "Pour 04 · Barrel Proof Finale",
    bottle: "Wild Turkey Rare Breed",
    proof: "116.8 proof",
    age: "6, 8 & 12 yr blend",
    score: "4.65",
    level: 0.93,
    note: "Cinnamon red-hot, burnt orange oil, and deep charred oak — the bottle the whole room remembers.",
    wheel: [0.72, 0.96, 0.92, 0.58, 0.42, 0.55, 0.2, 0.18]
  }
]

const GLASS_DROP = 28

export default class extends Controller {
  static targets = [
    "cinema", "hslide", "hdot",
    "theatre", "shell", "act", "dockBtn", "dockGlass",
    "deckCard", "carriedDeck",
    "rsvpBtn", "extraSeat", "rsvpCount",
    "pourBtn", "roomBadge", "roomBottle", "roomNote", "roomProof", "roomAge", "roomScore", "roomGlass",
    "verdictRow", "wheelTitle", "wheelScore", "wedge",
    "segBtn", "planCard"
  ]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.heroIdx = 0
    this.activeAct = 1
    this.baseGoing = parseInt(this.rsvpCountTarget?.dataset.base || "5", 10)
    this.rsvpIn = false

    this.onScroll = this.onScroll.bind(this)
    this.tick = this.tick.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })

    this.showHeroSlide(0)
    this.selectPourIndex(0)
    this.selectVerdictIndex(3)
    this.onScroll()

    if (!this.reduced) {
      this.heroTimer = setInterval(() => {
        if (!this.heroPaused) this.nextHeroSlide()
      }, 4800)
    }
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    clearInterval(this.heroTimer)
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  // --- Hero Slide Player ---
  pauseHero() { this.heroPaused = true }
  resumeHero() { this.heroPaused = false }

  nextHeroSlide() {
    if (!this.hslideTargets.length) return
    this.showHeroSlide((this.heroIdx + 1) % this.hslideTargets.length)
  }

  pickHeroSlide(event) {
    event.stopPropagation()
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    this.showHeroSlide(idx)
  }

  showHeroSlide(idx) {
    this.heroIdx = idx
    this.hslideTargets.forEach((el, i) => el.classList.toggle("is-active", i === idx))
    this.hdotTargets.forEach((el, i) => el.classList.toggle("is-active", i === idx))
  }

  // --- Scroll Choreography ---
  onScroll() {
    if (!this.raf) this.raf = requestAnimationFrame(this.tick)
  }

  tick() {
    this.raf = null

    // 1. Hero Cinema Perspective Rise
    if (this.hasCinemaTarget && !this.reduced) {
      const p = Math.min(1, Math.max(0, window.scrollY / 320))
      const tilt = (7 * (1 - p)).toFixed(2)
      const scale = (0.955 + 0.045 * p).toFixed(4)
      this.cinemaTarget.style.setProperty("--tilt", `${tilt}deg`)
      this.cinemaTarget.style.setProperty("--scale", scale)
    }

    // 2. Sticky 4-Act Theatre (Desktop >= 900px)
    if (this.hasTheatreTarget && window.innerWidth >= 900) {
      const rect = this.theatreTarget.getBoundingClientRect()
      const scrollable = Math.max(1, this.theatreTarget.offsetHeight - window.innerHeight)
      const progress = Math.min(1, Math.max(0, -rect.top / scrollable))

      // Fill the dock Glencairn 1:1 with scroll
      if (this.hasDockGlassTarget) {
        const drop = ((1 - progress) * GLASS_DROP).toFixed(2)
        this.dockGlassTarget.style.setProperty("--c1-glass-drop", `${drop}px`)
      }

      const act = Math.min(4, Math.floor(progress * 4) + 1)
      if (act !== this.activeAct) {
        this.setAct(act)
      }
    }
  }

  setAct(act) {
    this.activeAct = act
    if (this.hasShellTarget) this.shellTarget.dataset.act = String(act)
    this.actTargets.forEach((el, i) => el.classList.toggle("is-active", i + 1 === act))
    this.dockBtnTargets.forEach((el, i) => el.classList.toggle("is-active", i + 1 === act))
  }

  jumpAct(event) {
    const act = parseInt(event.currentTarget.dataset.act, 10)
    if (!this.hasTheatreTarget) return
    const top = this.theatreTarget.getBoundingClientRect().top + window.scrollY
    const scrollable = Math.max(1, this.theatreTarget.offsetHeight - window.innerHeight)
    const targetY = top + ((act - 0.65) / 4) * scrollable
    window.scrollTo({ top: Math.max(top, targetY), behavior: this.reduced ? "auto" : "smooth" })
    this.setAct(act)
  }

  // --- Act 1: Pick a Deck (carries title forward into Act 2 & Act 3) ---
  pickDeck(event) {
    const card = event.currentTarget
    const title = card.dataset.title
    this.deckCardTargets.forEach((el) => el.classList.toggle("is-picked", el === card))
    this.carriedDeckTargets.forEach((el) => { el.textContent = title })
  }

  // --- Act 2: Live RSVP Pour ---
  toggleRsvp() {
    this.rsvpIn = !this.rsvpIn
    if (this.hasExtraSeatTarget) this.extraSeatTarget.classList.toggle("is-seated", this.rsvpIn)
    if (this.hasRsvpBtnTarget) {
      this.rsvpBtnTarget.classList.toggle("is-in", this.rsvpIn)
      this.rsvpBtnTarget.textContent = this.rsvpIn ? "You're on the list ✓" : "Count me in"
    }
    if (this.hasRsvpCountTarget) {
      this.rsvpCountTarget.textContent = `${this.baseGoing + (this.rsvpIn ? 1 : 0)} going`
    }
  }

  // --- Act 3: Interactive 4-Pour Flight ---
  selectPour(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    this.selectPourIndex(idx)
  }

  selectPourIndex(idx) {
    const pour = POUR_DATA[idx] || POUR_DATA[0]
    this.pourBtnTargets.forEach((el, i) => el.classList.toggle("is-active", i === idx))
    if (this.hasRoomBadgeTarget) this.roomBadgeTarget.textContent = pour.num
    if (this.hasRoomBottleTarget) this.roomBottleTarget.textContent = pour.bottle
    if (this.hasRoomNoteTarget) this.roomNoteTarget.textContent = `“${pour.note}”`
    if (this.hasRoomProofTarget) this.roomProofTarget.textContent = pour.proof
    if (this.hasRoomAgeTarget) this.roomAgeTarget.textContent = pour.age
    if (this.hasRoomScoreTarget) this.roomScoreTarget.textContent = pour.score
    if (this.hasRoomGlassTarget) {
      const liquid = this.roomGlassTarget.querySelectorAll("g > path")
      const drop = ((1 - pour.level) * 24).toFixed(2)
      liquid.forEach((p) => { p.style.transform = `translateY(${drop}px)` })
    }
  }

  // --- Act 4: Live Morphing Palate Wheel ---
  selectVerdict(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    this.selectVerdictIndex(idx)
  }

  selectVerdictIndex(idx) {
    const pour = POUR_DATA[idx] || POUR_DATA[3]
    this.verdictRowTargets.forEach((el) => {
      el.classList.toggle("is-active", parseInt(el.dataset.index, 10) === idx)
    })
    if (this.hasWheelTitleTarget) this.wheelTitleTarget.textContent = pour.bottle
    if (this.hasWheelScoreTarget) this.wheelScoreTarget.textContent = `${pour.score} / 5`
    this.wedgeTargets.forEach((w, i) => {
      const v = pour.wheel[i] ?? 0.3
      const scale = (0.28 + v * 0.72).toFixed(3)
      w.style.transform = `scale(${scale})`
      w.style.opacity = (0.25 + v * 0.75).toFixed(2)
      w.setAttribute("fill", v >= 0.72 ? "#ff6d00" : (v >= 0.5 ? "#16332a" : "#8fa397"))
    })
  }

  // --- Pricing Segmented Highlighter ---
  highlightPlan(event) {
    const key = event.currentTarget.dataset.plan
    this.segBtnTargets.forEach((b) => b.classList.toggle("is-active", b.dataset.plan === key))
    this.planCardTargets.forEach((c) => c.classList.toggle("is-highlighted", c.dataset.plan === key))
  }
}
