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
//
// With a freeText target, unmatched typing is a valid answer rather than a
// dead end: the host field uses it for guest presenters who aren't members.
// Without one (the deck field), only a real record will do, because a deck
// has to exist to be attached.
export default class extends Controller {
  static targets = ["input", "hidden", "results", "freeText"]
  static values = { url: String, minLength: { type: Number, default: 0 } }

  connect() {
    // What the box said when it arrived, so typing can tell whether the
    // selection still stands.
    this.chosenLabel = this.inputTarget.value.trim()
    this.syncFreeText()
  }

  disconnect() { clearTimeout(this.timer) }

  query() {
    clearTimeout(this.timer)
    const typed = this.inputTarget.value.trim()

    // Typing something other than the chosen label drops the id. Without this
    // the form would submit a stale id while the field showed a different
    // name, which reads as picking someone and silently assigns another.
    if (typed !== this.chosenLabel) this.clearChoice()
    this.syncFreeText()

    if (typed.length < this.minLengthValue) { this.hide(); return }
    this.timer = setTimeout(() => this.fetch(typed), 150)
  }

  // Focus shows what's available, so an empty field isn't a dead end.
  open() {
    if (this.inputTarget.value.trim().length >= this.minLengthValue) this.query()
  }

  async fetch(q) {
    // Ignore responses that arrive out of order. Focusing the field fires one
    // fetch and typing fires another; on a slow connection the earlier request
    // can resolve LAST and clobber the correct results with stale ones (that
    // was the intermittent "member doesn't show" bug). Only the newest request
    // is allowed to render.
    const token = (this.requestToken = (this.requestToken || 0) + 1)

    let matches
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return
      matches = await response.json()
    } catch { return }

    if (token === this.requestToken) this.render(matches)
  }

  render(matches) {
    this.resultsTarget.textContent = ""

    if (!matches.length) {
      // Say what happens next, rather than leaving a dead end. Clicking is
      // optional (the text already submits), but a silent no-match reads as
      // "this won't work".
      const typed = this.inputTarget.value.trim()
      const none = document.createElement(this.hasFreeTextTarget && typed ? "button" : "p")
      if (this.hasFreeTextTarget && typed) {
        none.type = "button"
        none.textContent = `Use “${typed}” as a guest presenter`
        none.className = "block w-full px-3 py-2 text-left text-sm font-medium text-whiskey-700 hover:bg-whiskey-50"
        none.addEventListener("click", () => this.hide())
      } else {
        none.textContent = "Nothing matches."
        none.className = "px-3 py-2 text-sm text-gray-400"
      }
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
    this.syncFreeText()
    this.hide()
  }

  // The typed text submits only when no record was picked. Sending both would
  // leave the server guessing which the user meant.
  syncFreeText() {
    if (!this.hasFreeTextTarget) return

    this.freeTextTarget.value = this.hiddenTarget.value ? "" : this.inputTarget.value.trim()
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
