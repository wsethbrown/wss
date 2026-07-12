import { Controller } from "@hotwired/stimulus"

// Live search dropdown, three shapes:
//
// - Section mode (grouped: true), the /reviews page. Fetches the section
//   endpoint, which returns { bottles: [...], societies: [...] }; renders
//   grouped results. Deliberately NO "add a new bottle" row: a society name
//   or a typo must never become a junk catalog entry from here.
// - Picker mode (grouped: false, no bottleId target), the start-a-review
//   page. Fetches the bottle endpoint (a flat array); rows link to each
//   bottle's REVIEW form (review_url) and an explicit "+ Add …" escape
//   hatch is appended, because the intent to catalog is unambiguous there.
// - Fill mode (grouped: false, WITH a bottleId hidden-input target), the
//   event pour form. Clicking a row fills the hidden bottle_id instead of
//   navigating; the "+ Add …" escape carries return-to so the organizer
//   lands back on the event after cataloging.
//
// All rendering is textContent/createElement, user input never becomes HTML.
export default class extends Controller {
  static targets = ["input", "results", "bottleId"]
  static values = {
    url: String,
    grouped: { type: Boolean, default: false },
    returnTo: { type: String, default: "" }
  }

  query() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    if (q.length < 2) { this.resultsTarget.classList.add("hidden"); return }
    this.timer = setTimeout(() => this.fetch(q), 200)
  }

  async fetch(q) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
      headers: { Accept: "application/json" }
    })
    if (!response.ok) return
    const data = await response.json()
    this.groupedValue ? this.renderGroups(data) : this.renderPicker(data, q)
  }

  renderGroups(data) {
    this.resultsTarget.textContent = ""
    const groups = [["Distilleries", data.distilleries], ["Bottles", data.bottles], ["Societies", data.societies]]
    let any = false
    for (const [heading, items] of groups) {
      if (!items?.length) continue
      any = true
      this.resultsTarget.appendChild(this.heading(heading))
      for (const item of items) this.resultsTarget.appendChild(this.link(item.label, item.url))
    }
    if (!any) this.resultsTarget.appendChild(this.empty())
    this.resultsTarget.classList.remove("hidden")
  }

  renderPicker(matches, q) {
    this.resultsTarget.textContent = ""
    for (const match of matches) {
      if (this.hasBottleIdTarget) {
        this.resultsTarget.appendChild(this.fillRow(match))
      } else {
        this.resultsTarget.appendChild(this.link(match.display_name, match.review_url || match.url))
      }
    }
    let addHref = `/bottles/new?name=${encodeURIComponent(q)}`
    if (this.returnToValue) addHref += `&return_to=${encodeURIComponent(this.returnToValue)}`
    const add = this.link(`+ Add "${q}" as a new bottle`, addHref)
    add.classList.add("border-t", "border-gray-100", "font-medium", "text-whiskey-700")
    add.classList.remove("text-gray-800")
    this.resultsTarget.appendChild(add)
    this.resultsTarget.classList.remove("hidden")
  }

  fillRow(match) {
    const el = document.createElement("button")
    el.type = "button"
    el.textContent = match.display_name
    el.className = "block w-full text-left px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    el.addEventListener("click", () => {
      this.bottleIdTarget.value = match.id
      this.inputTarget.value = match.display_name
      this.resultsTarget.classList.add("hidden")
    })
    return el
  }

  heading(text) {
    const el = document.createElement("p")
    el.textContent = text
    el.className = "eyebrow border-b border-gray-100 bg-gray-50 px-4 py-1.5 text-gray-400"
    return el
  }

  link(text, href) {
    const el = document.createElement("a")
    el.href = href
    el.textContent = text
    el.className = "block px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    return el
  }

  empty() {
    const el = document.createElement("p")
    el.textContent = "Nothing on the record yet."
    el.className = "px-4 py-2.5 text-sm text-gray-400"
    return el
  }

  disconnect() { clearTimeout(this.timer) }
}
