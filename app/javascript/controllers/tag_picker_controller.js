import { Controller } from "@hotwired/stimulus"

// Multi-select flavor tags on a review page: toggle chips, then follow one
// link to /reviews?tags=... with every selected tag.
export default class extends Controller {
  static targets = ["chip", "go"]

  toggle(event) {
    event.preventDefault()
    const chip = event.currentTarget
    chip.dataset.on = chip.dataset.on === "1" ? "0" : "1"
    chip.classList.toggle("bg-whiskey-600", chip.dataset.on === "1")
    chip.classList.toggle("text-white", chip.dataset.on === "1")
    chip.classList.toggle("bg-whiskey-100", chip.dataset.on !== "1")
    chip.classList.toggle("text-whiskey-800", chip.dataset.on !== "1")
    this.refresh()
  }

  refresh() {
    const picked = this.chipTargets.filter(c => c.dataset.on === "1").map(c => c.dataset.tag)
    if (picked.length === 0) { this.goTarget.classList.add("hidden"); return }
    this.goTarget.href = `/reviews?tags=${encodeURIComponent(picked.join(","))}`
    this.goTarget.textContent = `Find tastings with ${picked.join(" + ")} →`
    this.goTarget.classList.remove("hidden")
  }
}
