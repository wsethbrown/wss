import { Controller } from "@hotwired/stimulus"

// Live search over the bottle catalog. Renders matches as links plus an
// "add a new bottle" escape hatch so the flow never dead-ends.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

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
    this.render(await response.json(), q)
  }

  render(matches, q) {
    this.resultsTarget.textContent = ""
    for (const match of matches) {
      const link = document.createElement("a")
      link.href = match.url
      link.textContent = match.display_name
      link.className = "block px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
      this.resultsTarget.appendChild(link)
    }
    const add = document.createElement("a")
    add.href = `/bottles/new?name=${encodeURIComponent(q)}`
    add.textContent = `+ Add "${q}" as a new bottle`
    add.className = "block border-t border-gray-100 px-4 py-2.5 font-medium text-whiskey-700 hover:bg-whiskey-50"
    this.resultsTarget.appendChild(add)
    this.resultsTarget.classList.remove("hidden")
  }

  disconnect() { clearTimeout(this.timer) }
}
