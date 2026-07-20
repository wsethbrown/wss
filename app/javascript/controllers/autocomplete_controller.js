import { Controller } from "@hotwired/stimulus"

// A plain id-picker: type to search, click a suggestion, submit the id.
//
// Deliberately separate from bottle_search, which carries a lot of
// bottle-specific behaviour (catalog-creation escape hatches, chip mode,
// prefill). This is the boring case: a text field standing in for a select,
// where the only outcome is "an id, or nothing".
//
// Clearing the field means "none". That is how the deck and host fields keep
// the ability to unset that the old dropdown had via its blank option, so the
// empty state has to submit cleanly rather than being treated as invalid.
export default class extends Controller {
  static targets = ["input", "hidden", "results", "empty"]
  static values = { url: String, minLength: { type: Number, default: 0 } }

  connect() {
    // What the box said when it arrived, so typing can tell whether the
    // selection still stands.
    this.chosenLabel = this.inputTarget.value.trim()
  }

  disconnect() { clearTimeout(this.timer) }

  query() {
    clearTimeout(this.timer)
    const typed = this.inputTarget.value.trim()

    // Typing something other than the chosen label drops the id. Without this
    // the form would submit a stale id while the field showed a different
    // name, which reads as picking someone and silently assigns another.
    if (typed !== this.chosenLabel) this.clearChoice()

    if (typed.length < this.minLengthValue) { this.hide(); return }
    this.timer = setTimeout(() => this.fetch(typed), 150)
  }

  // Focus shows what's available, so an empty field isn't a dead end.
  open() {
    if (this.inputTarget.value.trim().length >= this.minLengthValue) this.query()
  }

  async fetch(q) {
    let matches
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return
      matches = await response.json()
    } catch { return }

    this.render(matches)
  }

  render(matches) {
    this.resultsTarget.textContent = ""

    if (!matches.length) {
      const none = document.createElement("p")
      none.textContent = "Nothing matches."
      none.className = "px-3 py-2 text-sm text-gray-400"
      this.resultsTarget.appendChild(none)
    }

    for (const match of matches) {
      const row = document.createElement("button")
      row.type = "button"
      // textContent, never innerHTML: these labels are user-entered names.
      row.textContent = match.label
      row.className = "block w-full px-3 py-2 text-left text-sm text-gray-800 hover:bg-whiskey-50"
      row.addEventListener("click", () => this.choose(match))
      this.resultsTarget.appendChild(row)
    }

    this.resultsTarget.classList.remove("hidden")
  }

  choose(match) {
    this.hiddenTarget.value = match.id
    this.inputTarget.value = match.label
    this.chosenLabel = match.label
    this.hide()
  }

  clearChoice() {
    this.hiddenTarget.value = ""
    this.chosenLabel = null
  }

  hide() { this.resultsTarget.classList.add("hidden") }

  // A click elsewhere closes the list. Blur alone would fire before the
  // click on a suggestion registers, so picking one would never take.
  clickOutside(event) {
    if (!this.element.contains(event.target)) this.hide()
  }
}
