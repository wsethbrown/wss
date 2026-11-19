import { Controller } from "@hotwired/stimulus"

// Fills the story thread (the thin line beside the deck story) to match
// reading progress through the section. Listeners live only while the
// controller is connected, so Turbo visits never stack them.
export default class extends Controller {
  static targets = ["thread"]

  connect() {
    this.update = this.update.bind(this)
    window.addEventListener("scroll", this.update, { passive: true })
    window.addEventListener("resize", this.update, { passive: true })
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.update)
    window.removeEventListener("resize", this.update)
  }

  update() {
    if (!this.hasThreadTarget) return
    const rect = this.element.getBoundingClientRect()
    const viewport = window.innerHeight
    const total = rect.height - viewport * 0.5
    const progress = total > 0 ? Math.min(1, Math.max(0, (viewport * 0.5 - rect.top) / total)) : 1
    this.threadTarget.style.height = `${(progress * 100).toFixed(1)}%`
  }
}
