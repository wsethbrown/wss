import { Controller } from "@hotwired/stimulus"

// The site's one reveal system (docs/redesign/DESIGN_SYSTEM.md, "Motion").
// Lives on the public layout's <main>. Kinds of target:
//
//   item    A card, list row, panel or section heading. Out of view at load,
//           it waits hidden (.appear-pending) and, the first time it scrolls
//           in properly (its top about a fifth of the way up the screen),
//           eases up and fades in (.is-in, a 700ms CSS transition), with a
//           short shrinking stagger across the items that arrive together.
//   glass   A shared/_glass svg. Its level rises (a 1.2s CSS animation) the
//           first time it is seen.
//   draw    A palate wheel or flavor wave svg. Its wedges, stems and line
//           draw in (CSS animations under .draw-run, 1.25s at most).
//   perform A homepage step face's screen. Its rows, avatars or record play
//           once (.perform-run, 950ms at most; the CSS is in home/index).
//   photo   A shared/_duotone figure. Its photograph settles from a slight
//           scale inside the frame (.photo-run).
//   image   An img that may still be loading. If it has not loaded when it
//           connects, it fades in when it does (.img-wait, .img-in).
//
// glass, draw, perform and photo are secondary motion: each waits in its
// start state until it is well on screen (it reaches the middle 60% of the
// viewport) and then plays once, so it plays where the eye is. One inside a
// revealing item starts at least 120ms after its item starts to show (never
// while the item is still hidden), and is shown at once whenever its item
// is. A wheel or wave already on screen when a Turbo visit lands plays
// 300ms later (not on a back or forward visit, and not on a full page load,
// which may already have painted it finished), so an above-the-fold drawing
// reached by a click is seen to draw.
//
// On a wide screen the homepage faces are sticky: they slide up and pin in
// place. Motion inside one (marked data-appear-settle) waits until the face
// has settled, then plays, so it is not spent while the face is still
// travelling. Settled: at its pinned spot and the one on top; or the page
// can scroll no further; or the reader has stopped (150ms) with the face all
// or very nearly all (90%) in view. A reader who stops with the face still
// partly below the fold gets the motion after HELD_IDLE of stillness, so
// nothing stays in a start state.
//
// The triggers sit inside the viewport, so while the page scrolls an item
// can be on screen and still waiting. When the scroll settles (150ms) that
// band is emptied: everything waiting on screen starts its motion, except
// motion held for a pinned face that is not yet settled (above), which
// starts once the face settles or after HELD_IDLE of stillness.
//
// Safety rules, each one a bug this replaced or could have caused:
// - The hidden start state is a class this controller adds, never server
//   HTML, so no JS (or a JS error) means everything is simply visible.
// - Anything already on screen when the controller connects is left alone
//   (except the draw-ins above): it was painted visible, and hiding it to
//   fade it back would flicker.
// - Time-based and once: an item that starts revealing always finishes, and
//   then its classes are removed so its own hover styles are untouched.
//   (The old homepage reveal was scrubbed by scroll position and stayed
//   part-faded wherever the scroll stopped.)
// - Nothing on screen can stay hidden, even if the observer never fires:
//   when the scroll (or a resize) settles, anything waiting above the bottom
//   of the screen is revealed (or, if a jump carried it past, shown at once);
//   a one-off time limit after load does the same for items; motion held
//   for a pinned face starts when the face settles, when the scroll stops
//   with the face (nearly) all in view, or once the page has been still for
//   HELD_IDLE whatever its position; and focusing anything
//   inside a waiting item shows that item at once, so a keyboard user never
//   lands on something invisible.
// - Before Turbo caches the page, everything is finished, so a cached
//   snapshot (back button, preview) never shows hidden content, and a back
//   or forward visit hides nothing again.
// - Never hidden: an item taller than about a screen (TALL). Fading a whole
//   page of reading text is worse than no reveal, and on a phone it builds a
//   huge layer. Mark such a section's heading instead.
// - Under prefers-reduced-motion: reduce the controller does nothing at all.
// - An image is only hidden if it has not loaded yet; it is shown at once if
//   it fails, if it has sat on screen for IMAGE_LIMIT without loading, and
//   before Turbo caches the page.

const DURATION = 700 // ms, matches .appear-pending.is-in in application.css
const POUR = 1200 // ms, matches svg[data-glass].glass-pouring
// Where things start: an item once its top is above the bottom 18% of the
// screen; secondary motion once it reaches the middle 60%.
const ITEM_MARGIN = "0px 0px -18% 0px"
// Phones start a reveal a little earlier, so a section eases in as it rises
// instead of appearing abruptly (owner, November 2026).
const PHONE_ITEM_MARGIN = "0px 0px -9% 0px"
// "not all and (min-width)" rather than max-width: no gap at 639.5px.
const PHONE = "not all and (min-width: 640px)"
const DEEP_MARGIN = "-20% 0px -20% 0px"
const ON_LOAD = 300 // ms: an on-screen draw-in or pour at load starts after this
const REPOUR = 500 // ms: a glass whose level a Turbo stream changed moves to it
const POUR_EASE = "cubic-bezier(0.2, 0.7, 0.2, 1)" // --motion-ease-pour
const STAGGER = [ 0, 60, 110, 150, 180, 200 ] // ms; gaps shrink, then cap
const ITEM = "[data-appear-target~='item']"
const SETTLE = 150 // ms after the last scroll or resize event
// Motion held for a pinned face that has stopped short of its spot (the
// reader paused with it partly below the fold) starts once the page has been
// still this long: it is no longer travelling, and nothing may stay hidden.
const HELD_IDLE = 1000 // ms after the last scroll
const LIMIT = 1500 // ms after targets are sorted: the one-off safety net
const TALL = 1.2 // x the viewport height: an item this tall is never hidden
const POUR_LAG = 120 // ms: secondary motion in a revealing card starts once the card shows
// The secondary kinds: the class holding the start state, the class that
// plays it, and how long it plays (the longest delay plus duration in CSS).
const KINDS = {
  glass: { wait: "glass-wait", run: "glass-pouring", ms: POUR },
  draw: { wait: "draw-wait", run: "draw-run", ms: 1250 },
  perform: { wait: "perform-wait", run: "perform-run", ms: 950 },
  photo: { wait: "photo-wait", run: "photo-run", ms: 1200 }
}
const ALL_CLASSES = [ "appear-pending", "is-in", ...Object.values(KINDS).flatMap((k) => [ k.wait, k.run ]) ]
const IMAGE_FADE = 200 // ms, matches img.img-in
const IMAGE_LIMIT = 2000 // ms on screen without loading: show it anyway
const IMAGE_CHECK = 500 // ms between those checks

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
  static targets = [ "item", "glass", "draw", "perform", "photo", "image" ]

  // Stimulus calls the target callbacks before connect(), so both go
  // through setup().
  connect() { this.setup() }

  disconnect() {
    if (!this.active) return
    this.finishAll()
    this.observer.disconnect()
    this.deep.disconnect()
    if (this.phone.removeEventListener) this.phone.removeEventListener("change", this.onPhoneChange)
    document.removeEventListener("turbo:before-cache", this.finishAll)
    document.removeEventListener("turbo:before-stream-render", this.onStream)
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    this.element.removeEventListener("focusin", this.onFocus)
    clearTimeout(this.settleTimer)
    clearTimeout(this.lateTimer)
    clearTimeout(this.limitTimer)
    this.limitTimer = null
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
    if (this.heldFrame) cancelAnimationFrame(this.heldFrame)
    this.heldFrame = null
    clearInterval(this.imageTimer)
    this.imageTimer = null
    this.active = false
    this.ready = false
  }

  itemTargetConnected(el) { this.enqueue(el, "item") }
  glassTargetConnected(el) { this.enqueue(el, "glass") }
  drawTargetConnected(el) { this.enqueue(el, "draw") }
  performTargetConnected(el) { this.enqueue(el, "perform") }
  photoTargetConnected(el) { this.enqueue(el, "photo") }
  imageTargetConnected(el) { this.watchImage(el) }
  // Removed by a Turbo stream or a re-render: stop watching it.
  itemTargetDisconnected(el) { this.forget(el) }
  glassTargetDisconnected(el) { this.forget(el) }
  drawTargetDisconnected(el) { this.forget(el) }
  performTargetDisconnected(el) { this.forget(el) }
  photoTargetDisconnected(el) { this.forget(el) }
  imageTargetDisconnected(el) { if (this.active) this.showImage(el) }

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
    // Only a Turbo render is certain not to have been painted yet. A full
    // load can paint a finished drawing before this runs (measured in Chrome
    // and WebKit), so a draw-in there would flash: drawn, collapsed, redrawn.
    this.turbo = turboRendering
    this.restoring = restoring
    this.queue = new Set()
    this.waiting = new Set()       // hidden, observed
    this.running = new Map()       // element -> timer
    this.delays = new WeakMap()    // item -> its stagger delay
    this.shows = new WeakMap()     // item -> when it starts to show (ms, performance.now)
    this.kinds = new WeakMap()     // element -> "item", "glass", "draw", ...
    this.images = new Map()        // loading img -> ms it has spent on screen
    this.finishAll = this.finishAll.bind(this)
    this.onIntersect = this.onIntersect.bind(this)
    this.onScroll = this.onScroll.bind(this)
    this.onFocus = this.onFocus.bind(this)
    // Inset triggers, so motion happens where the eye is. The band they
    // leave (on screen, still waiting) is emptied when the scroll settles.
    // The item trigger depends on the screen size, so it is rebuilt if the
    // phone query flips (a rotation, a resized window).
    this.phone = window.matchMedia(PHONE)
    this.observer = this.itemObserver()
    this.onPhoneChange = this.onPhoneChange.bind(this)
    if (this.phone.addEventListener) this.phone.addEventListener("change", this.onPhoneChange)
    this.held = new Set()          // secondary motion waiting for its pinned face to settle
    this.deep = new IntersectionObserver(this.onIntersect, { rootMargin: DEEP_MARGIN })
    document.addEventListener("turbo:before-cache", this.finishAll)
    this.onStream = this.onStream.bind(this)
    document.addEventListener("turbo:before-stream-render", this.onStream)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    this.element.addEventListener("focusin", this.onFocus)
    return true
  }

  enqueue(el, kind) {
    if (!this.setup()) return
    this.kinds.set(el, kind)
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
      const secondary = this.kinds.get(el) !== "item"
      // One entrance per container: an item inside another item rides along.
      if (!secondary && el.parentElement && el.parentElement.closest(ITEM)) continue
      if (this.restoring) continue
      sorted.push({ el, secondary, rect: el.getBoundingClientRect() })
    }
    this.queue.clear()
    const fresh = this.fresh
    const turbo = this.turbo
    this.fresh = false
    this.turbo = false
    this.restoring = false

    // On screen at load: a draw-in or a pour plays (after ON_LOAD) on a
    // Turbo visit, which is not painted until this has run, so a finished
    // drawing is never shown and then collapsed. On a full page load it may
    // already have been painted final, so it stays final (as it did in
    // batch 1, where a glass poured on load only before the first paint).
    const nowPlay = []
    for (const { el, secondary, rect } of sorted) {
      const below = rect.top >= height || (rect.width === 0 && rect.height === 0)
      if (!secondary && rect.height > height * TALL) continue
      if (!below) {
        const kind = this.kinds.get(el)
        // A glass keeps batch 1's rule (pours if not yet painted).
        const playable = kind === "draw" ? turbo : fresh
        if (secondary && rect.bottom > 0 && playable) nowPlay.push(el)
        continue
      }
      this.prepare(el)
      this.waiting.add(el)
      this.watcher(el).observe(el)
    }
    nowPlay.forEach((el) => {
      const kind = this.kinds.get(el)
      this.prepare(el)
      this.start(el, kind === "draw" || kind === "glass" ? ON_LOAD : 0)
    })

    // The one-off safety net: whatever is still waiting on screen by now is
    // revealed, observer or not.
    if (this.waiting.size && !this.limitTimer) {
      this.limitTimer = setTimeout(() => { this.limitTimer = null; this.sweep() }, LIMIT)
    }
  }

  itemObserver() {
    return new IntersectionObserver(this.onIntersect, { rootMargin: this.phone.matches ? PHONE_ITEM_MARGIN : ITEM_MARGIN })
  }

  onPhoneChange() {
    if (!this.active) return
    this.observer.disconnect()
    this.observer = this.itemObserver()
    for (const el of this.waiting) if (this.kinds.get(el) === "item") this.observer.observe(el)
    this.onScroll()
  }

  watcher(el) { return this.kinds.get(el) === "item" ? this.observer : this.deep }

  prepare(el) {
    const kind = this.kinds.get(el)
    if (kind === "item") return el.classList.add("appear-pending")
    if (kind === "glass") {
      const level = parseFloat(el.dataset.glass) || 0
      if (level < 0.02) return
      // Start just under the bowl's foot whatever the level, so a low pour
      // starts rising at once instead of waiting below the glass.
      el.style.setProperty("--glass-rise", `${(level * 34 + 4).toFixed(1)}px`)
    }
    el.classList.add(KINDS[kind].wait)
  }

  onIntersect(entries) {
    this.reveal(entries.filter((entry) => entry.isIntersecting && this.waiting.has(entry.target))
      .map((entry) => ({ target: entry.target, rect: entry.boundingClientRect })))
  }

  // Start the reveal of a batch arriving together, top to bottom, left to
  // right, with the shrinking stagger.
  // force: false (start held motion only once its face has settled),
  // "idle" (the scroll has stopped: also start a face that is all, or very
  // nearly all, in view), "late" (still for HELD_IDLE: start everything).
  reveal(arriving, force = false) {
    if (!arriving.length) return
    arriving.sort((a, b) => (a.rect.top - b.rect.top) || (a.rect.left - b.rect.left))

    let step = 0
    for (const { target } of arriving) {
      if (this.kinds.get(target) !== "item" || !this.waiting.has(target)) continue
      const delay = STAGGER[Math.min(step++, STAGGER.length - 1)]
      this.delays.set(target, delay)
      this.start(target, delay)
    }
    for (const { target } of arriving) {
      if (this.kinds.get(target) === "item" || !this.waiting.has(target)) continue
      // Inside a pinned (sticky) container that is still sliding into
      // place: hold it until the container has settled, so it plays where
      // it will stay and not while it travels.
      // The page is still if the scroll has settled (an idle sweep) or a
      // layout shift with no scroll brought this in (late fonts, images).
      const idle = force === "idle" || (!force && this.pageIdle())
      if (force !== "late" && this.unsettled(target) && !(idle && this.inView(target) && !this.covered(target))) {
        // Stopped with the face covered by a later one (Page Down, End, a
        // scrollbar jump): nobody can see it, so show it finished rather
        // than spend the motion unseen.
        if (idle && this.covered(target)) { this.held.delete(target); this.finish(target); continue }
        this.held.add(target); this.checkHeldSoon()
        if (idle) this.holdLate()
        continue
      }
      this.held.delete(target)
      // Inside a card still waiting: the card goes first (it is further
      // into view than its own trigger needs).
      const card = target.parentElement && target.parentElement.closest(ITEM)
      if (card && this.waiting.has(card)) this.start(card, 0)
      // Never before the card has been showing for POUR_LAG, so the motion
      // is not spent while the card is still faint.
      const shows = card && this.running.has(card) ? this.shows.get(card) : null
      const delay = shows == null ? 0 : Math.max(0, Math.round(shows + POUR_LAG - performance.now()))
      this.start(target, delay)
    }
  }

  start(el, delay) {
    const kind = this.kinds.get(el)
    this.waiting.delete(el)
    this.watcher(el).unobserve(el)
    if (kind === "item") {
      el.style.setProperty("--appear-delay", `${delay}ms`)
      el.classList.add("is-in")
      this.shows.set(el, performance.now() + delay)
      this.running.set(el, setTimeout(() => this.finish(el), DURATION + delay + 60))
      // Its secondary motion waits for its own, deeper trigger.
      return
    }
    const { wait, run, ms } = KINDS[kind]
    if (!el.classList.contains(wait)) return // nothing to play (an empty glass)
    el.style.setProperty("--appear-delay", `${delay}ms`)
    el.classList.remove(wait)
    el.classList.add(run)
    this.running.set(el, setTimeout(() => this.finish(el), ms + delay + 60))
  }

  waitingInside(item) {
    return [ ...this.waiting ].filter((el) => el !== item && this.kinds.get(el) !== "item" && item.contains(el))
  }

  // Back to the element's own styles: no classes, no variables left behind.
  // An item shown without its reveal takes its waiting secondary motion
  // with it, so nothing inside is left in a start state.
  finish(el) {
    const skipped = this.waiting.has(el) && this.kinds.get(el) === "item"
    clearTimeout(this.running.get(el))
    this.running.delete(el)
    this.waiting.delete(el)
    if (this.observer) this.watcher(el).unobserve(el)
    el.classList.remove(...ALL_CLASSES)
    el.style.removeProperty("--appear-delay")
    el.style.removeProperty("--glass-rise")
    if (skipped) this.waitingInside(el).forEach((inner) => this.finish(inner))
  }

  finishAll() {
    if (!this.active) return
    for (const el of [ ...this.waiting, ...this.running.keys() ]) this.finish(el)
    for (const img of [ ...this.images.keys() ]) this.showImage(img)
  }

  // An image still loading when it connects waits invisible and fades in
  // once it has loaded. Already loaded (a cached image, a back visit): left
  // alone, so there is no flash. Fails, or sits on screen for IMAGE_LIMIT
  // without loading (or the page is cached by Turbo): shown at once.
  watchImage(img) {
    if (!this.setup() || restoring || img.complete || this.images.has(img)) return
    // Not rendered (display: none, e.g. a photo for wide screens only on a
    // phone): nothing to fade, and it would wait forever. Left alone.
    const rects = img.getClientRects()
    if (!rects.length) return
    // On screen after the first paint, it may already be partly drawn:
    // hiding it to fade it back would flash. Left alone.
    if (painted() && !turboRendering && rects[0].top < window.innerHeight && rects[0].bottom > 0) return
    this.images.set(img, 0)
    img.classList.add("img-wait")
    img.addEventListener("load", () => this.fadeImage(img), { once: true })
    img.addEventListener("error", () => this.showImage(img), { once: true })
    if (!this.imageTimer) this.imageTimer = setInterval(() => this.checkImages(), IMAGE_CHECK)
  }

  fadeImage(img) {
    if (!this.images.has(img)) return
    this.images.delete(img)
    img.classList.add("img-in")
    img.classList.remove("img-wait")
    setTimeout(() => img.classList.remove("img-in"), IMAGE_FADE + 60)
    this.stopImageTimer()
  }

  showImage(img) {
    this.images.delete(img)
    img.classList.remove("img-wait", "img-in")
    this.stopImageTimer()
  }

  stopImageTimer() {
    if (this.images.size || !this.imageTimer) return
    clearInterval(this.imageTimer)
    this.imageTimer = null
  }

  // While a waiting image is on screen, check twice a second; once none
  // is, stop, and let the next scroll settle start the checks again.
  checkImages() {
    const height = window.innerHeight
    let anyOnScreen = false
    for (const [ img, shown ] of [ ...this.images ]) {
      if (!img.isConnected) { this.showImage(img); continue }
      const rect = img.getBoundingClientRect()
      const onScreen = rect.bottom > 0 && rect.top < height && rect.width > 0
      const time = onScreen ? shown + IMAGE_CHECK : 0
      if (time >= IMAGE_LIMIT) this.showImage(img)
      else { this.images.set(img, time); if (onScreen) anyOnScreen = true }
    }
    if (!anyOnScreen && this.imageTimer) { clearInterval(this.imageTimer); this.imageTimer = null }
  }

  // When the scroll or a resize settles, nothing waiting above the bottom
  // of the screen stays hidden. Usually the observer has already revealed
  // it; this catches the cases it cannot: a jump that carried an item from
  // below the viewport to above it between two frames, or an observer that
  // never fires at all.
  onScroll() {
    this.lastScroll = performance.now()
    if (this.held.size) this.checkHeldSoon()
    clearTimeout(this.settleTimer)
    this.settleTimer = setTimeout(() => this.sweep(), SETTLE)
  }

  sweep() {
    if (!this.active) return
    if (this.images.size && !this.imageTimer) {
      this.imageTimer = setInterval(() => this.checkImages(), IMAGE_CHECK)
      this.checkImages()
    }
    if (!this.waiting.size) return
    const height = window.innerHeight
    const measured = [ ...this.waiting ].map((el) => ({ target: el, rect: el.isConnected ? el.getBoundingClientRect() : null }))
    const onScreen = []
    for (const { target, rect } of measured) {
      if (!rect || rect.bottom <= 0) this.finish(target) // gone, or passed: show at once
      else if (rect.top < height) onScreen.push({ target, rect })
    }
    // Once the scroll has stopped, everything waiting on screen starts, so
    // nothing is left in a start state; motion held for a pinned face starts
    // only if the face is (nearly) all in view, else after HELD_IDLE. (The one-off
    // time limit can land mid-scroll; then a sliding face keeps waiting for
    // its spot, and the settle after the scroll starts it at the latest.)
    this.reveal(onScreen, this.pageIdle() ? "idle" : false)
  }

  // A face held while the page is still: start it once the page has stayed
  // still for HELD_IDLE (cancelled by any scroll, which re-arms the sweep).
  holdLate() {
    clearTimeout(this.lateTimer)
    this.lateTimer = setTimeout(() => {
      if (!this.active || !this.held.size) return
      if (this.lastScroll && performance.now() - this.lastScroll < HELD_IDLE - 20) return
      const height = window.innerHeight
      const late = []
      for (const el of [ ...this.held ]) {
        this.held.delete(el)
        if (!this.waiting.has(el) || !el.isConnected) continue
        const rect = el.getBoundingClientRect()
        if (rect.bottom <= 0 || this.covered(el)) this.finish(el) // passed, or out of sight under a later face
        else if (rect.top < height) late.push({ target: el, rect })
        else this.held.add(el)
      }
      this.reveal(late, "late")
    }, HELD_IDLE - SETTLE)
  }

  pageIdle() {
    return !this.lastScroll || performance.now() - this.lastScroll >= SETTLE - 10
  }

  // A later sticky face has slid over the face around el.
  covered(el) {
    const box = el.closest("[data-appear-settle]")
    if (!box || getComputedStyle(box).position !== "sticky") return false
    const top = box.getBoundingClientRect().top
    for (let next = box.nextElementSibling; next; next = next.nextElementSibling) {
      if (next.matches("[data-appear-settle]") && next.getBoundingClientRect().top <= top + 1) return true
    }
    return false
  }

  // The face around el is all, or very nearly all (90%), on screen.
  inView(el) {
    const box = el.closest("[data-appear-settle]") || el
    const rect = box.getBoundingClientRect()
    if (!rect.height) return true
    const shown = Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0)
    return shown / rect.height >= 0.9
  }

  // A sticky container marked data-appear-settle (a homepage face) has
  // settled when it sits at its pinned top and no later container has
  // slid over it. Not sticky (phones, where the faces are a plain stack):
  // nothing to wait for.
  unsettled(el) {
    const box = el.closest("[data-appear-settle]")
    if (!box) return false
    const style = getComputedStyle(box)
    if (style.position !== "sticky") return false
    const pinned = parseFloat(style.top)
    if (Number.isNaN(pinned)) return false
    const top = box.getBoundingClientRect().top
    // The page cannot scroll any further, so the face has come as far into
    // place as it ever will: that is its settled spot.
    const atEnd = window.scrollY >= document.documentElement.scrollHeight - window.innerHeight - 1
    if (Math.abs(top - pinned) > 1 && !atEnd) return true
    return this.covered(el)
  }

  checkHeldSoon() {
    if (this.heldFrame) return
    this.heldFrame = requestAnimationFrame(() => {
      this.heldFrame = null
      const ready = []
      for (const el of [ ...this.held ]) {
        if (!this.waiting.has(el) || !el.isConnected) { this.held.delete(el); continue }
        // Scrolled back up past it: show it finished and stop checking it.
        if (el.getBoundingClientRect().bottom <= 0) { this.held.delete(el); this.finish(el); continue }
        if (!this.unsettled(el)) ready.push({ target: el, rect: el.getBoundingClientRect() })
      }
      if (ready.length) { ready.forEach(({ target }) => this.held.delete(target)); this.reveal(ready, "late") }
    })
  }

  // The re-pour. A Turbo stream that replaces a region holding glasses
  // marked data-repour (the RSVP table, events/_table) would make each
  // changed glass jump to its new level. Instead: note the old levels
  // before the swap; after it, each glass on screen whose level changed
  // starts its liquid at the old level and moves to the new one over
  // REPOUR on the pour curve (Web Animations, so no class or style is left
  // behind and the drawn level is always the final one). Seats are matched
  // in order. Nothing under reduced motion (this controller does nothing),
  // nothing off screen, and a glass emptied to nothing simply shows empty.
  onStream(event) {
    const id = event.target.getAttribute && event.target.getAttribute("target")
    const region = id && document.getElementById(id)
    if (!region || !region.querySelector("[data-repour]")) return
    const before = [ ...region.querySelectorAll("[data-repour] svg[data-glass]") ].map((g) => parseFloat(g.dataset.glass) || 0)
    const render = event.detail.render
    event.detail.render = async (stream) => {
      await render(stream)
      // Motion is decoration: it must never make the stream's render fail.
      try { this.repour(id, before) } catch (_) { /* no re-pour, the level is drawn */ }
    }
  }

  repour(id, before) {
    const region = document.getElementById(id)
    if (!this.active || !region) return
    const height = window.innerHeight
    region.querySelectorAll("[data-repour] svg[data-glass]").forEach((glass, i) => {
      if (i >= before.length) return
      const from = before[i]
      const to = parseFloat(glass.dataset.glass) || 0
      if (to < 0.02 || Math.abs(to - from) < 0.01) return
      const rect = glass.getBoundingClientRect()
      if (rect.bottom <= 0 || rect.top >= height) return
      // The drawing's own units: a level is 34 tall; empty sits 4 below the bowl.
      const drop = from < 0.02 ? to * 34 + 4 : (to - from) * 34
      const paths = [ ...glass.querySelectorAll("g > path") ]
      if (!paths.length || typeof paths[0].animate !== "function") return
      // A falling level lifts the liquid to start from the old surface; its
      // body only reaches so far down, so a still copy of the body at the
      // new level stays underneath and keeps the bowl full below the surface.
      let under = null
      if (drop < 0) {
        under = paths[0].cloneNode()
        paths[0].before(under)
      }
      try {
        const animations = paths.map((path) =>
          path.animate([ { transform: `translateY(${drop.toFixed(2)}px)` }, { transform: "none" } ], { duration: REPOUR, easing: POUR_EASE }))
        if (under) Promise.all(animations.map((a) => a.finished)).catch(() => {}).finally(() => under.remove())
      } catch (_) {
        // No Web Animations: the new level is simply drawn.
        if (under) under.remove()
      }
    })
  }

  // A keyboard user must never focus something invisible: show the item
  // (and any item around it) at once, without waiting for the fade.
  onFocus(event) {
    let item = event.target.closest(ITEM)
    while (item) {
      if (this.waiting.has(item) || this.running.has(item)) this.finish(item)
      item = item.parentElement && item.parentElement.closest(ITEM)
    }
    // And any draw-in, face, pour or photo around it, waiting or playing.
    for (const el of [ ...this.waiting, ...this.running.keys() ]) {
      if (this.kinds.get(el) !== "item" && el.contains(event.target)) this.finish(el)
    }
  }
}
