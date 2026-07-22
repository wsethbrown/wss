import { Controller } from "@hotwired/stimulus"

// The event RSVP segmented control: a fill that slides between answers.
//
// WHY JS OWNS THIS. The answer posts to the server, and any turbo stream that
// re-rendered this region — replace or morph — tore the indicator out
// mid-transition, so the fill snapped to its new spot instead of travelling
// there. So the control is client-owned: the streams re-render the note, the
// counts and the attendee list, but never this. The server is still the source
// of truth for what was recorded; this owns how it looks getting there.
//
// The move is optimistic, starting on press rather than on the response, so it
// feels immediate on a slow connection. If the request fails, revert() puts
// both the fill and aria-pressed back where they were.
//
// Everything except position hangs off aria-pressed in CSS, so this only ever
// flips one attribute and never builds markup.
export default class extends Controller {
  static targets = ["indicator", "option"]

  connect() {
    // Placed, not animated: otherwise it slides in from the left on every load.
    this.settle({ animate: false })

    // Labels reflow (late font swap, container resize), so re-measure rather
    // than trusting the first measurement forever.
    //
    // But NOT while the user is mid-slide. Revealing the tick widens the
    // pressed button, which resizes this group, which fires the observer —
    // and an instant re-place cancels the very transition that was running.
    // That is why the fill used to snap instead of slide.
    this.observer = new ResizeObserver(() => {
      if (this.sliding) return
      this.settle({ animate: false })
    })
    this.observer.observe(this.element)

    // The slide is over when the transform lands.
    this.onSettled = (event) => {
      if (event.propertyName === "transform") this.sliding = false
    }
    this.indicatorTarget?.addEventListener("transitionend", this.onSettled)
    this.indicatorTarget?.addEventListener("transitioncancel", this.onSettled)
  }

  disconnect() {
    this.observer?.disconnect()
    this.indicatorTarget?.removeEventListener("transitionend", this.onSettled)
    this.indicatorTarget?.removeEventListener("transitioncancel", this.onSettled)
  }

  // Move the fill to whichever option is currently marked chosen.
  settle({ animate = true } = {}) {
    const option = this.chosen()
    if (!option || !this.hasIndicatorTarget) return

    const indicator = this.indicatorTarget
    if (!animate) indicator.classList.add("is-instant")

    indicator.style.width = `${option.offsetWidth}px`
    indicator.style.transform = `translateX(${option.offsetLeft}px)`
    indicator.dataset.fill = option.dataset.answer
    indicator.dataset.fillResting = option.dataset.resting || "false"

    if (!animate) {
      // Flush before transitions come back, or removing the class and moving
      // land in the same frame and it animates anyway.
      void indicator.offsetWidth
      indicator.classList.remove("is-instant")
    }
  }

  pick(event) {
    const option = event.currentTarget
    if (option.getAttribute("aria-pressed") === "true") return

    // Remember the truth we had, so a failed request can be undone.
    this.previous = this.optionTargets.find((o) => o.getAttribute("aria-pressed") === "true") || null
    this.previousResting = this.optionTargets.find((o) => o.dataset.resting === "true") || null

    // Hold the resize observer off until the fill has finished travelling.
    this.sliding = true
    clearTimeout(this.slideTimer)
    // Belt and braces: transitionend won't fire if the tab is hidden or the
    // move is a no-op, and a stuck flag would freeze re-measuring for good.
    this.slideTimer = setTimeout(() => { this.sliding = false }, 600)

    this.select(option)
    option.classList.add("is-answering")

    // Restart the pop: re-adding a class the element already carries does
    // nothing, so drop it and force a reflow first.
    const indicator = this.indicatorTarget
    indicator.classList.remove("is-popping")
    void indicator.offsetWidth
    indicator.classList.add("is-popping")
  }

  // The server refused (offline, RSVPs just closed, permissions). Showing an
  // answer that was never recorded is worse than not animating at all.
  submitEnd(event) {
    if (event.detail?.success) return

    this.optionTargets.forEach((o) => {
      o.setAttribute("aria-pressed", "false")
      o.classList.remove("is-answering")
      delete o.dataset.resting
    })
    if (this.previous) this.previous.setAttribute("aria-pressed", "true")
    if (this.previousResting) this.previousResting.dataset.resting = "true"
    this.settle()
  }

  select(option) {
    this.optionTargets.forEach((o) => {
      o.setAttribute("aria-pressed", String(o === option))
      // Resting is the pre-answer state only; once anything is chosen it's gone.
      delete o.dataset.resting
      if (o !== option) o.classList.remove("is-answering")
    })
    this.settle()
  }

  chosen() {
    return this.optionTargets.find((o) => o.getAttribute("aria-pressed") === "true") ||
           this.optionTargets.find((o) => o.dataset.resting === "true")
  }
}
