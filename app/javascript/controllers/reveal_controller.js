import { Controller } from "@hotwired/stimulus"

// A field that stays out of the way until asked for: the "Replace" and
// "Add files" buttons on the admin deck page's file rows. Without
// JavaScript the content shows and the button stays hidden; with it the
// content folds away unless open (an empty slot, or a field in error), and
// the button brings it back.
export default class extends Controller {
  static targets = ["content", "button", "field"]
  static values = { open: Boolean }

  connect() {
    if (!this.hasButtonTarget) return
    this.buttonTarget.hidden = false
    this.set(this.openValue)
  }

  toggle() {
    const opening = this.contentTarget.hidden
    this.set(opening)
    if (opening && this.hasFieldTarget) this.fieldTarget.focus()
  }

  set(open) {
    this.contentTarget.hidden = !open
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
  }
}
