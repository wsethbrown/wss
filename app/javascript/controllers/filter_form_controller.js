import { Controller } from "@hotwired/stimulus"

// Live filters for the library: typing in the search field submits the form
// after a short pause, and changing any select submits at once. The Filter
// button (data-filter-form-target="submit") is the no-JavaScript fallback and
// is hidden on connect. Attach to the form; mark the search input with
// data-filter-form-target="search" and each select with
// data-filter-form-target="select". Timer is cleared on disconnect, so Turbo
// visits never leave a pending or duplicate submit behind.
export default class extends Controller {
  static targets = ["search", "select", "submit"]
  static values = { delay: { type: Number, default: 500 } }

  // The form submits itself on input and change, so the no-JavaScript submit
  // button is redundant here; hide it instead of leaving a control that looks
  // required.
  submitTargetConnected(button) {
    button.hidden = true
  }

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
