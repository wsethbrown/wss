import { Controller } from "@hotwired/stimulus"

// Live filters for the library: typing in the search field submits the form
// after a short pause, and changing any select submits at once, so there is no
// Apply button. Attach to the form; mark the search input with
// data-filter-form-target="search" and each select with
// data-filter-form-target="select". Timer is cleared on disconnect, so Turbo
// visits never leave a pending or duplicate submit behind.
export default class extends Controller {
  static targets = ["search", "select"]
  static values = { delay: { type: Number, default: 500 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  queue() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submit(), this.delayValue)
  }

  submit() {
    clearTimeout(this.timer)
    this.element.requestSubmit()
  }
}
