import { Controller } from "@hotwired/stimulus"

// TRIAL, off by default (home/_story_glass.html.erb, rendered only for
// /?glass=1). A glass that fills as the reader scrolls through the homepage
// story: empty when the first step's words sit in the middle of the screen,
// full when the closing beat's heading does. To drop the trial, delete this
// file and the partial (the partial says what else goes).
//
// The drawing is shared/_glass at full; this lowers its liquid by
// --story-glass-drop (user units, as the pour does). The level follows the
// scroll position directly, with no easing of its own, so it is always
// exactly where the reader is. Under reduced motion it does not follow the
// scroll: it steps a third at a time as each step is reached.
// On phones (fixed in the gutter) it is shown only while the steps are on
// screen; on desktop it rides with the pinned faces and the CSS shows it.

const DROP = 38 // the full level lowered this far is below the bowl: empty

export default class extends Controller {
  connect() {
    const story = this.element.closest(".story")
    this.first = story && story.querySelector(".b2 .beat-body")
    this.close = story && story.querySelector(".beat--close h2")
    if (!this.first || !this.close) return
    this.marks = [ ".b3 .beat-body", ".b4 .beat-body", ".beat--close h2" ].map((s) => story.querySelector(s)).filter(Boolean)
    this.reduce = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.schedule = this.schedule.bind(this)
    window.addEventListener("scroll", this.schedule, { passive: true })
    window.addEventListener("resize", this.schedule, { passive: true })
    this.update()
    this.element.hidden = false
  }

  disconnect() {
    window.removeEventListener("scroll", this.schedule)
    window.removeEventListener("resize", this.schedule)
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
  }

  schedule() {
    if (!this.frame) this.frame = requestAnimationFrame(() => this.update())
  }

  update() {
    this.frame = null
    const mid = window.innerHeight / 2
    const centre = (el) => { const r = el.getBoundingClientRect(); return r.top + r.height / 2 }
    let level
    if (this.reduce.matches) {
      level = this.marks.filter((el) => centre(el) <= mid).length / this.marks.length
    } else {
      const from = centre(this.first)
      const to = centre(this.close)
      level = to > from ? Math.min(1, Math.max(0, (mid - from) / (to - from))) : 1
    }
    this.element.style.setProperty("--story-glass-drop", `${((1 - level) * DROP).toFixed(2)}px`)

    const top = this.first.getBoundingClientRect().top
    const bottom = this.close.getBoundingClientRect().bottom
    this.element.classList.toggle("is-shown", top < window.innerHeight && bottom > 0)
  }
}
