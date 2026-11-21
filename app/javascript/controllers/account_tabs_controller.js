import { Controller } from "@hotwired/stimulus"

const TAB_BASE = "inline-flex min-h-11 items-center gap-2.5 rounded-xl border px-3.5 text-sm font-medium md:w-full group"
const TAB_ACTIVE = `${TAB_BASE} border-ink bg-ink text-white`
const TAB_IDLE = `${TAB_BASE} border-hairline bg-white text-ink transition hover:border-whiskey-300`

// Account page sections as an ARIA tab set. Tabs are the [data-tab] links in the
// nav; panels are the .tab-content blocks (#<tab>-content). Supports click,
// in-panel [data-tab-link] links, the URL hash, the legacy ?subscription param,
// and arrow/Home/End keys. All listeners are removed in disconnect().
export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.element.addEventListener("click", this.onClick)
    this.element.addEventListener("keydown", this.onKeydown)

    this.tabs.forEach((tab) => {
      const name = tab.dataset.tab
      tab.setAttribute("role", "tab")
      tab.id = `tab-${name}`
      tab.setAttribute("aria-controls", `${name}-content`)
    })
    this.panels.forEach((panel) => {
      const name = panel.id.replace(/-content$/, "")
      panel.setAttribute("role", "tabpanel")
      panel.setAttribute("aria-labelledby", `tab-${name}`)
    })
    this.tabs[0]?.parentElement?.setAttribute("role", "tablist")

    const params = new URLSearchParams(window.location.search)
    const hash = window.location.hash.substring(1)
    if (params.has("subscription")) {
      this.activate("subscription")
    } else if (hash && document.getElementById(`${hash}-content`)) {
      this.activate(hash)
    } else {
      this.activate(this.tabs.find((t) => t.getAttribute("aria-selected") === "true")?.dataset.tab || this.tabs[0]?.dataset.tab, { scroll: false })
    }

    // Readiness signal for system tests: set last, once listeners are bound and
    // the initial tab is active, so a click after this point cannot be lost.
    this.element.setAttribute("data-account-tabs-ready", "true")
  }

  disconnect() {
    this.element.removeAttribute("data-account-tabs-ready")
    this.element.removeEventListener("click", this.onClick)
    this.element.removeEventListener("keydown", this.onKeydown)
  }

  get tabs() { return Array.from(this.element.querySelectorAll("[data-tab]")) }
  get panels() { return Array.from(this.element.querySelectorAll(".tab-content")) }

  onClick(event) {
    const link = event.target.closest("[data-tab-link]")
    const tab = link ? null : event.target.closest("[data-tab]")
    const name = link?.dataset.tabLink || tab?.dataset.tab
    if (!name) return
    event.preventDefault()
    this.activate(name)
    // Native anchor navigation is suppressed, so mirror the tab into the hash.
    history.replaceState(null, "", `#${name}`)
  }

  onKeydown(event) {
    const current = event.target.closest("[data-tab]")
    if (!current) return
    const tabs = this.tabs
    const index = tabs.indexOf(current)
    let next
    switch (event.key) {
      case "ArrowDown":
      case "ArrowRight": next = tabs[(index + 1) % tabs.length]; break
      case "ArrowUp":
      case "ArrowLeft": next = tabs[(index - 1 + tabs.length) % tabs.length]; break
      case "Home": next = tabs[0]; break
      case "End": next = tabs[tabs.length - 1]; break
      default: return
    }
    event.preventDefault()
    this.activate(next.dataset.tab, { scroll: false })
    next.focus()
    history.replaceState(null, "", `#${next.dataset.tab}`)
  }

  activate(name, { scroll = true } = {}) {
    if (!name) return
    this.tabs.forEach((tab) => {
      const active = tab.dataset.tab === name
      tab.className = active ? TAB_ACTIVE : TAB_IDLE
      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.tabIndex = active ? 0 : -1
      const icon = tab.querySelector("svg")
      if (icon) icon.setAttribute("class", `h-5 w-5 shrink-0 ${active ? "text-white" : "text-mute"}`)
    })
    this.panels.forEach((panel) => panel.classList.add("hidden"))
    const target = document.getElementById(`${name}-content`)
    if (!target) return
    target.classList.remove("hidden")
    if (!scroll) return

    // When scrolled deep into a long panel, swapping content above the fold looks
    // like the click did nothing, so bring the new panel into view only if needed.
    const panelTop = target.getBoundingClientRect().top + window.scrollY - 96
    if (window.scrollY > panelTop) {
      const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
      window.scrollTo({ top: Math.max(panelTop, 0), behavior: reduce ? "auto" : "smooth" })
    }
  }
}
