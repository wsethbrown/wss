import { Controller } from "@hotwired/stimulus"

// The site's one reveal system (docs/redesign/DESIGN_SYSTEM.md, "Motion").
// Lives on the public layout's <main>. Two kinds of target:
//
//   item   A card, list row, panel or section heading. Out of view at load,
//          it waits hidden (.appear-pending) and, the first time it scrolls
//          in, eases up and fades in (.is-in, a 500ms CSS transition), with
//          a short shrinking stagger across the items that arrive together.
//   glass  A shared/_glass svg. Its level rises (a 900ms CSS animation) the
//          first time it is seen.
//
// Safety rules, each one a bug this replaced or could have caused:
// - The hidden start state is a class this controller adds, never server
//   HTML, so no JS (or a JS error) means everything is simply visible.
// - Anything already on screen when the controller connects is left alone:
//   it was painted visible, and hiding it to fade it back would flicker.
// - Time-based and once: an item that starts revealing always finishes, and
//   then its classes are removed so its own hover styles are untouched.
//   (The old homepage reveal was scrubbed by scroll position and stayed
//   part-faded wherever the scroll stopped.)
// - Nothing on screen can stay hidden, even if the observer never fires:
//   when the scroll (or a resize) settles, anything waiting above the bottom
//   of the screen is revealed (or, if a jump carried it past, shown at once);
//   a one-off time limit after load does the same; and focusing anything
//   inside a waiting item shows that item at once, so a keyboard user never
//   lands on something invisible.
// - Before Turbo caches the page, everything is finished, so a cached
//   snapshot (back button, preview) never shows hidden content, and a back
//   or forward visit hides nothing again.
// - Never hidden: an item taller than about a screen (TALL). Fading a whole
//   page of reading text is worse than no reveal, and on a phone it builds a
//   huge layer. Mark such a section's heading instead.
// - Under prefers-reduced-motion: reduce the controller does nothing at all.

const DURATION = 500 // ms, matches .appear-pending.is-in in application.css
const POUR = 900 // ms, matches svg[data-glass].glass-pouring
const STAGGER = [ 0, 60, 110, 150, 180, 200 ] // ms; gaps shrink, then cap
const ITEM = "[data-appear-target~='item']"
const SETTLE = 150 // ms after the last scroll or resize event
const LIMIT = 1500 // ms after targets are sorted: the one-off safety net
const TALL = 1.2 // x the viewport height: an item this tall is never hidden
const POUR_LAG = 120 // ms: a glass in a revealing card pours once the card shows

// A Turbo render inserts the new page before it is painted, so a glass on
// screen can pour without first flashing full. On a first, full page load
// the module runs after the first paint, so it cannot.
let turboRendering = false
document.addEventListener("turbo:before-render", () => { turboRendering = true })
document.addEventListener("turbo:render", () => { setTimeout(() => { turboRendering = false }, 0) })

// A back or forward visit puts the page back the way the reader left it:
// nothing is hidden again. (The controller connects before Turbo restores
// the scroll position, so it cannot tell what will be on screen.)
let restoring = false
document.addEventListener("turbo:visit", (event) => { restoring = event.detail.action === "restore" })
document.addEventListener("turbo:load", () => { setTimeout(() => { restoring = false }, 0) })

function painted() {
  try {
    return performance.getEntriesByType("paint").some((entry) => entry.name === "first-contentful-paint")
  } catch (_) {
    return true
  }
}

export default class extends Controller {
  static targets = [ "item", "glass" ]

  // Stimulus calls the target callbacks before connect(), so both go
  // through setup().
  connect() { this.setup() }

  disconnect() {
    if (!this.active) return
    this.finishAll()
    this.observer.disconnect()
    document.removeEventListener("turbo:before-cache", this.finishAll)
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    this.element.removeEventListener("focusin", this.onFocus)
    clearTimeout(this.settleTimer)
    clearTimeout(this.limitTimer)
    this.limitTimer = null
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
    this.active = false
    this.ready = false
  }

  itemTargetConnected(el) { this.enqueue(el) }
  glassTargetConnected(el) { this.enqueue(el) }
  // Removed by a Turbo stream or a re-render: stop watching it.
  itemTargetDisconnected(el) { this.forget(el) }
  glassTargetDisconnected(el) { this.forget(el) }

  forget(el) {
    if (!this.active) return
    this.queue.delete(el)
    if (this.waiting.has(el) || this.running.has(el)) this.finish(el)
  }

  setup() {
    if (this.ready) return this.active
    this.ready = true
    this.active = "IntersectionObserver" in window &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (!this.active) return false

    this.fresh = turboRendering || !painted()
    this.restoring = restoring
    this.queue = new Set()
    this.waiting = new Set()       // hidden, observed
    this.running = new Map()       // element -> timer
    this.delays = new WeakMap()    // item -> its stagger delay
    this.finishAll = this.finishAll.bind(this)
    this.onIntersect = this.onIntersect.bind(this)
    this.onScroll = this.onScroll.bind(this)
    this.onFocus = this.onFocus.bind(this)
    // No inset margin: an item reveals as soon as any of it is on screen, so
    // nothing can sit hidden in a band at the bottom of the viewport.
    this.observer = new IntersectionObserver(this.onIntersect)
    document.addEventListener("turbo:before-cache", this.finishAll)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    this.element.addEventListener("focusin", this.onFocus)
    return true
  }

  enqueue(el) {
    if (!this.setup()) return
    this.queue.add(el)
    if (!this.frame) this.frame = requestAnimationFrame(() => this.classify())
  }

  // Sort the new targets into on screen (left alone, or a glass that pours
  // now) and below the fold (hidden and observed). Runs before the next
  // paint, after Turbo has restored a back-navigation's scroll position.
  classify() {
    this.frame = null
    const height = window.innerHeight
    // Read every position first, then write classes, so the browser lays
    // the page out once.
    const sorted = []
    for (const el of this.queue) {
      if (!el.isConnected || this.waiting.has(el) || this.running.has(el)) continue
      const glass = el.matches("svg[data-glass]")
      // One entrance per container: an item inside another item rides along.
      if (!glass && el.parentElement && el.parentElement.closest(ITEM)) continue
      if (this.restoring) continue
      sorted.push({ el, glass, rect: el.getBoundingClientRect() })
    }
    this.queue.clear()
    const fresh = this.fresh
    this.fresh = false
    this.restoring = false

    const nowPour = []
    for (const { el, glass, rect } of sorted) {
      const below = rect.top >= height || (rect.width === 0 && rect.height === 0)
      if (!glass && rect.height > height * TALL) continue
      if (!below) {
        if (glass && fresh && rect.bottom > 0) nowPour.push(el)
        continue
      }
      this.prepare(el, glass)
      this.waiting.add(el)
      this.observer.observe(el)
    }
    nowPour.forEach((el) => { this.prepare(el, true); this.start(el, true, 0) })

    // The one-off safety net: whatever is still waiting on screen by now is
    // revealed, observer or not.
    if (this.waiting.size && !this.limitTimer) {
      this.limitTimer = setTimeout(() => { this.limitTimer = null; this.sweep() }, LIMIT)
    }
  }

  prepare(el, glass) {
    if (glass) {
      const level = parseFloat(el.dataset.glass) || 0
      if (level < 0.02) return
      // Start just under the bowl's foot whatever the level, so a low pour
      // starts rising at once instead of waiting below the glass.
      el.style.setProperty("--glass-rise", `${(level * 34 + 4).toFixed(1)}px`)
      el.classList.add("glass-wait")
    } else {
      el.classList.add("appear-pending")
    }
  }

  onIntersect(entries) {
    this.reveal(entries.filter((entry) => entry.isIntersecting && this.waiting.has(entry.target))
      .map((entry) => ({ target: entry.target, rect: entry.boundingClientRect })))
  }

  // Start the reveal of a batch arriving together, top to bottom, left to
  // right, with the shrinking stagger.
  reveal(arriving) {
    if (!arriving.length) return
    arriving.sort((a, b) => (a.rect.top - b.rect.top) || (a.rect.left - b.rect.left))

    let step = 0
    for (const { target } of arriving) {
      if (target.matches("svg[data-glass]")) continue
      const delay = STAGGER[Math.min(step++, STAGGER.length - 1)]
      this.delays.set(target, delay)
      this.start(target, false, delay)
    }
    for (const { target } of arriving) {
      if (!target.matches("svg[data-glass]")) continue
      // A glass inside a revealing card pours just after its card starts to
      // show, so the rise is not spent while the card is still faint.
      const card = target.closest(ITEM)
      const delay = card && this.running.has(card) ? (this.delays.get(card) || 0) + POUR_LAG : 0
      this.start(target, true, delay)
    }
  }

  start(el, glass, delay) {
    this.waiting.delete(el)
    this.observer.unobserve(el)
    if (glass && !el.classList.contains("glass-wait")) return
    el.style.setProperty("--appear-delay", `${delay}ms`)
    if (glass) {
      el.classList.remove("glass-wait")
      el.classList.add("glass-pouring")
    } else {
      el.classList.add("is-in")
    }
    const timer = setTimeout(() => this.finish(el), (glass ? POUR : DURATION) + delay + 60)
    this.running.set(el, timer)
  }

  // Back to the element's own styles: no classes, no variables left behind.
  finish(el) {
    clearTimeout(this.running.get(el))
    this.running.delete(el)
    this.waiting.delete(el)
    if (this.observer) this.observer.unobserve(el)
    el.classList.remove("appear-pending", "is-in", "glass-wait", "glass-pouring")
    el.style.removeProperty("--appear-delay")
    el.style.removeProperty("--glass-rise")
  }

  finishAll() {
    if (!this.active) return
    for (const el of [ ...this.waiting, ...this.running.keys() ]) this.finish(el)
  }

  // When the scroll or a resize settles, nothing waiting above the bottom
  // of the screen stays hidden. Usually the observer has already revealed
  // it; this catches the cases it cannot: a jump that carried an item from
  // below the viewport to above it between two frames, or an observer that
  // never fires at all.
  onScroll() {
    clearTimeout(this.settleTimer)
    this.settleTimer = setTimeout(() => this.sweep(), SETTLE)
  }

  sweep() {
    if (!this.active || !this.waiting.size) return
    const height = window.innerHeight
    const measured = [ ...this.waiting ].map((el) => ({ target: el, rect: el.isConnected ? el.getBoundingClientRect() : null }))
    const onScreen = []
    for (const { target, rect } of measured) {
      if (!rect || rect.bottom <= 0) this.finish(target) // gone, or passed: show at once
      else if (rect.top < height) onScreen.push({ target, rect })
    }
    this.reveal(onScreen)
  }

  // A keyboard user must never focus something invisible: show the item
  // (and any item around it) at once, without waiting for the fade.
  onFocus(event) {
    let item = event.target.closest(ITEM)
    while (item) {
      if (this.waiting.has(item) || this.running.has(item)) this.finish(item)
      item = item.parentElement && item.parentElement.closest(ITEM)
    }
  }
}
