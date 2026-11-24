import { Controller } from "@hotwired/stimulus"

// A row that scrolls sideways (the deck filters and tags on a phone) fades
// out at whichever edge has more to scroll, so it reads as "more this way"
// rather than being cut off. The fade itself is CSS (.scroll-row in
// application.css, a mask); this only says which edges have more:
// data-more-start and data-more-end on the row. Nothing to scroll (a wide
// screen, where the row wraps or fits): no attributes, so no fade. Without
// JS the row simply scrolls, as before.
//
// Re-measured when the row scrolls, when the row or any item in it changes
// size (web fonts arriving, the filter form hiding its no-JS button), and
// when items are added or removed.
//
// Keyboard focus: browsers leave a focused item that is already partly in
// view where it is, which can leave it (and its focus ring) under the fade
// or past the edge. On focus, an item within the fade's reach is scrolled
// fully clear of it (the row's scroll-padding is wider than the fade).
export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    this.schedule = () => { if (!this.frame) this.frame = requestAnimationFrame(this.update) }
    this.element.addEventListener("scroll", this.schedule, { passive: true })
    this.onFocus = this.onFocus.bind(this)
    this.element.addEventListener("focusin", this.onFocus)
    this.resize = new ResizeObserver(this.schedule)
    this.observeAll()
    this.mutations = new MutationObserver(() => { this.observeAll(); this.schedule() })
    this.mutations.observe(this.element, { childList: true, subtree: true, attributes: true, attributeFilter: [ "hidden", "class", "style" ] })
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => { if (this.resize) this.schedule() })
    this.update()
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.schedule)
    this.element.removeEventListener("focusin", this.onFocus)
    this.resize.disconnect()
    this.mutations.disconnect()
    this.resize = null
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
  }

  observeAll() {
    this.resize.disconnect()
    this.resize.observe(this.element)
    for (const child of this.element.children) this.resize.observe(child)
  }

  onFocus(event) {
    const row = this.element.getBoundingClientRect()
    const item = event.target.getBoundingClientRect()
    const reach = 48 // the row's scroll-padding-inline: clear of the 40px fade and the ring
    if (item.left < row.left + reach || item.right > row.right - reach) {
      event.target.scrollIntoView({ block: "nearest", inline: "nearest" })
    }
  }

  update() {
    this.frame = null
    const el = this.element
    const max = el.scrollWidth - el.clientWidth
    const left = Math.abs(el.scrollLeft)
    el.toggleAttribute("data-more-start", max > 1 && left > 1)
    el.toggleAttribute("data-more-end", max > 1 && left < max - 1)
  }
}
