import { Controller } from "@hotwired/stimulus"

// @mention autocomplete inside a textarea (Table talk on an event page).
//
// Different problem from the field autocomplete: there is no hidden id and no
// single value. The comment is plain text, so this only helps the author type
// a handle correctly, and the server resolves that text later (see Mentions).
// If they ignore the suggestions and type something nobody matches, that is
// fine and stays plain text, which is the behaviour the owner asked for.
//
// Only the word being typed at the caret is considered, so an @handle already
// written earlier in the comment is left alone.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  disconnect() { clearTimeout(this.timer) }

  type() {
    clearTimeout(this.timer)
    const fragment = this.activeMention()

    if (fragment === null) { this.hide(); return }
    this.timer = setTimeout(() => this.fetch(fragment), 150)
  }

  // The partial handle immediately before the caret, or null if the caret
  // isn't in one. Requires the @ to start a word so an email address mid-word
  // ("me@example") never opens the menu.
  activeMention() {
    const caret = this.inputTarget.selectionStart
    const before = this.inputTarget.value.slice(0, caret)
    const match = before.match(/(?:^|[\s(])@([A-Za-z0-9]*)$/)
    if (!match) return null

    this.mentionStart = caret - match[1].length - 1
    return match[1]
  }

  async fetch(fragment) {
    let matches
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(fragment)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return
      matches = await response.json()
    } catch { return }

    this.render(matches)
  }

  render(matches) {
    this.resultsTarget.textContent = ""
    if (!matches.length) { this.hide(); return }

    this.matches = matches
    this.rows = []
    // The top match is highlighted by default, so Tab/Enter completes it with
    // no arrowing — the common case is "type a few letters, tab, done".
    this.activeIndex = 0

    matches.forEach((match, index) => {
      const row = document.createElement("button")
      row.type = "button"
      row.className = "block w-full px-3 py-2 text-left text-sm"

      // createElement/textContent throughout: these are member-supplied names
      // being rendered next to a comment box, never innerHTML.
      const handle = document.createElement("span")
      handle.textContent = `@${match.handle}`
      handle.className = "font-semibold text-gray-900"
      const name = document.createElement("span")
      name.textContent = ` ${match.name}`
      name.className = "text-gray-500"

      row.append(handle, name)
      row.addEventListener("mousedown", (event) => {
        // mousedown, not click: the textarea blurs first otherwise and the
        // caret position this insert depends on is already gone.
        event.preventDefault()
        this.insert(match.handle)
      })
      // Hovering moves the highlight, so mouse and keyboard agree on "active".
      row.addEventListener("mousemove", () => this.highlight(index))
      this.rows.push(row)
      this.resultsTarget.appendChild(row)
    })

    this.highlight(0)
    this.resultsTarget.classList.remove("hidden")
  }

  // Keyboard nav while the menu is open. When it's closed, every key falls
  // through untouched — Tab still moves focus, Enter still adds a newline.
  keydown(event) {
    if (!this.open) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.highlight((this.activeIndex + 1) % this.rows.length)
        break
      case "ArrowUp":
        event.preventDefault()
        this.highlight((this.activeIndex - 1 + this.rows.length) % this.rows.length)
        break
      case "Tab":
      case "Enter":
        // Complete the highlighted match. preventDefault stops Tab leaving the
        // box and stops Enter inserting a newline — but only with the menu up.
        event.preventDefault()
        this.insert(this.matches[this.activeIndex].handle)
        break
      case "Escape":
        event.preventDefault()
        this.hide()
        break
    }
  }

  highlight(index) {
    this.activeIndex = index
    this.rows.forEach((row, i) => {
      row.classList.toggle("bg-whiskey-100", i === index)
      row.classList.toggle("bg-transparent", i !== index)
    })
  }

  get open() {
    return this.hasResultsTarget && !this.resultsTarget.classList.contains("hidden") && this.rows?.length > 0
  }

  insert(handle) {
    const input = this.inputTarget
    const caret = input.selectionStart
    const before = input.value.slice(0, this.mentionStart)
    const after = input.value.slice(caret)

    input.value = `${before}@${handle} ${after}`
    const position = before.length + handle.length + 2
    input.setSelectionRange(position, position)
    input.focus()
    this.hide()
  }

  hide() { this.resultsTarget.classList.add("hidden") }

  clickOutside(event) {
    if (!this.element.contains(event.target)) this.hide()
  }
}
