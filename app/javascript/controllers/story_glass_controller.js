import { Controller } from "@hotwired/stimulus"

// The story glass (home/_story_glass.html.erb, on the homepage only): a
// glass that fills as the reader scrolls through the homepage story, empty
// until the first step's words come up over the bottom edge of the screen,
// full when the closing beat's heading is mid-screen. Loaded like every controller (eager, from the
// import map); it is small, and inert on any page without its element.
//
// The drawing is shared/_glass at full; this lowers its liquid by
// --story-glass-drop (user units, as the pour does). The level follows the
// scroll position directly, with no easing of its own, so it is always
// exactly where the reader is. Under reduced motion it does not follow the
// scroll: it steps a third at a time as each step is reached.
// On phones (fixed in the bottom-right corner) it is shown only while the
// steps are on screen; on desktop it is sticky beside the steps and the CSS
// shows it.

const DROP = 28 // shared/_glass's span (24) + 4: the full level lowered this far is below the bowl, empty

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
      // Starts filling as the first step's words come up over the bottom edge
      // of the screen (owner: "start pouring earlier"; it used to start only
      // once they reached the middle), full when the closing heading's centre
      // reaches the middle. Both move 1:1 with the scroll, so this is linear.
      const start = this.first.getBoundingClientRect().top - window.innerHeight // 0 when the words appear
      const end = centre(this.close) - mid // 0 when the closing heading is mid-screen
      level = end > start ? Math.min(1, Math.max(0, -start / (end - start))) : 1
    }
    this.element.style.setProperty("--story-glass-drop", `${((1 - level) * DROP).toFixed(2)}px`)

    const top = this.first.getBoundingClientRect().top
    const bottom = this.close.getBoundingClientRect().bottom
    this.element.classList.toggle("is-shown", top < window.innerHeight && bottom > 0)
  }
}
