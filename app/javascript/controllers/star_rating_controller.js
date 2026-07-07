import { Controller } from "@hotwired/stimulus"

// Clickable star input: five stars, each made of two half-star zones, so
// ratings run 0.5–5.0 in halves. Hover previews; click commits to the
// hidden field. Fill is painted by sizing each star's amber overlay to
// 0% / 50% / 100%.
export default class extends Controller {
  static targets = ["value", "star", "label"]

  connect() {
    this.paint(this.current())
  }

  current() {
    return parseFloat(this.valueTarget.value) || 0
  }

  preview(event) {
    this.paint(parseFloat(event.currentTarget.dataset.value))
  }

  restore() {
    this.paint(this.current())
  }

  set(event) {
    event.preventDefault()
    this.valueTarget.value = event.currentTarget.dataset.value
    this.paint(this.current())
  }

  paint(value) {
    this.starTargets.forEach((star, i) => {
      const fill = Math.max(0, Math.min(1, value - i))
      star.querySelector("[data-fill]").style.width = `${fill * 100}%`
    })
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = value > 0 ? `${value % 1 === 0 ? value : value.toFixed(1)} / 5` : "Pick a rating"
    }
  }
}
