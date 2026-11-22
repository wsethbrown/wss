import { Controller } from "@hotwired/stimulus"

// The admin deck page's six tabs (admin/presentations/edit).
//
// Without JavaScript every pane is on the page and the tab row is a row of
// jump links (#pane-slides). This controller turns them into tabs: one pane
// shows at a time, the tab goes into location.hash (#slides), and the hash
// is read back on load, so a save that redirects to edit#pours lands on the
// Pour list. A pane can be more than one element (the Files tab is split
// around the deck form); every element with that data-pane shows together.
//
// Which tab opens on load, first match wins:
//   1. the tab holding the first field in error (the server re-rendered the
//      form with errors),
//   2. location.hash (#slides, #pane-slides, or an id inside a pane),
//   3. the form's hidden "tab" field (kept on a re-render),
//   4. Overview.
//
// The hidden "tab" field follows the open tab, so Save returns here.
// Any link to "#pane-x" or to an id inside a pane switches tabs instead of
// jumping, so the Overview's "Edit the pour list →" links just work.
//
// The tabs stay ordinary links in the Tab order. The left and right arrow
// keys are left to the Slides and script tab, which steps through slides.
export default class extends Controller {
  static targets = ["tab", "pane", "field", "tablist", "form"]

  connect() {
    this.tablistTarget.setAttribute("role", "tablist")
    this.tabTargets.forEach(tab => {
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-controls", `pane-${tab.dataset.tab}`)
    })
    this.paneTargets.forEach(pane => {
      pane.setAttribute("role", "tabpanel")
      pane.setAttribute("aria-labelledby", `tab-${pane.dataset.pane}`)
    })

    this.onClick = this.onClick.bind(this)
    this.element.addEventListener("click", this.onClick)
    // A link elsewhere to edit#files, or the back button over replaced hashes.
    this.onHashChange = this.onHashChange.bind(this)
    window.addEventListener("hashchange", this.onHashChange)

    // A field that fails the browser's own validation on a hidden tab would
    // block Save silently (the browser cannot point at a hidden field). The
    // "invalid" event doesn't bubble, so listen in the capture phase and open
    // the tab holding the first one before the browser looks for it.
    this.onInvalid = this.onInvalid.bind(this)
    if (this.hasFormTarget) this.formTarget.addEventListener("invalid", this.onInvalid, true)

    const { tab, target } = this.initialTab()
    this.show(tab, { updateHash: false })
    if (target) requestAnimationFrame(() => target.scrollIntoView({ block: "start" }))
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
    window.removeEventListener("hashchange", this.onHashChange)
    if (this.hasFormTarget) this.formTarget.removeEventListener("invalid", this.onInvalid, true)
  }

  get names() {
    return this.tabTargets.map(tab => tab.dataset.tab)
  }

  initialTab() {
    const invalid = this.element.querySelector("[data-pane] .field_with_errors, [data-pane] [aria-invalid=true]")
    if (invalid) return { tab: invalid.closest("[data-pane]").dataset.pane, target: invalid }

    const fromHash = this.resolve(window.location.hash)
    if (fromHash) return fromHash

    const kept = this.hasFieldTarget ? this.fieldTarget.value : null
    if (this.names.includes(kept)) return { tab: kept, target: null }

    return { tab: this.names[0], target: null }
  }

  // "#slides" or "#pane-slides" names a tab; "#publish" is an element inside
  // one. Returns { tab, target } (target: the element to scroll to, if any).
  resolve(hash) {
    const id = decodeURIComponent((hash || "").replace(/^#/, ""))
    if (!id) return null
    if (this.names.includes(id)) return { tab: id, target: null }
    const bare = id.replace(/^pane-/, "")
    if (this.names.includes(bare)) return { tab: bare, target: null }

    const element = document.getElementById(id)
    const pane = element && this.element.contains(element) ? element.closest("[data-pane]") : null
    return pane ? { tab: pane.dataset.pane, target: element } : null
  }

  onInvalid(event) {
    if (this.openedForInvalid) return
    const pane = event.target.closest("[data-pane]")
    if (!pane) return
    this.openedForInvalid = true
    setTimeout(() => { this.openedForInvalid = false }, 0)
    // A closed pour row (<details>) hides its fields too.
    const row = event.target.closest("details")
    if (row) row.open = true
    if (pane.dataset.pane !== this.current) this.show(pane.dataset.pane)
  }

  onHashChange() {
    const found = this.resolve(window.location.hash)
    if (found && found.tab !== this.current) this.show(found.tab, { updateHash: false })
  }

  onClick(event) {
    const link = event.target.closest("a[href^='#']")
    if (!link || !this.element.contains(link)) return
    const found = this.resolve(link.getAttribute("href"))
    if (!found) return

    event.preventDefault()
    this.show(found.tab)
    if (found.target) {
      found.target.scrollIntoView({ behavior: "smooth", block: "start" })
    } else {
      this.scrollToTop()
    }
    if (link.dataset.deckTabsTarget === "tab") link.focus()
  }

  show(name, { updateHash = true } = {}) {
    this.current = name
    this.tabTargets.forEach(tab => {
      const selected = tab.dataset.tab === name
      tab.setAttribute("aria-selected", selected ? "true" : "false")
    })
    this.paneTargets.forEach(pane => { pane.hidden = pane.dataset.pane !== name })
    if (this.hasFieldTarget) this.fieldTarget.value = name
    if (updateHash) history.replaceState(history.state, "", `#${name}`)

    const active = this.tabTargets.find(tab => tab.dataset.tab === name)
    active?.scrollIntoView?.({ block: "nearest", inline: "nearest" })
    this.dispatch("shown", { detail: { tab: name } })
  }

  // After switching from deep in a long pane, start the new one at its top.
  scrollToTop() {
    const top = this.element.getBoundingClientRect().top + window.scrollY
    if (window.scrollY > top) window.scrollTo({ top })
  }
}
