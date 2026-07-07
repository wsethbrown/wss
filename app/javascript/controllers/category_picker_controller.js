import { Controller } from "@hotwired/stimulus"

// A real dropdown of existing categories with a "+ New category…" escape
// hatch. Only one control is enabled at a time (disabled fields don't
// submit), so the form always sends exactly one category value.
export default class extends Controller {
  static targets = ["select", "input", "inputWrapper"]

  change() {
    if (this.selectTarget.value !== "__new__") return
    this.selectTarget.disabled = true
    this.selectTarget.classList.add("hidden")
    this.inputTarget.disabled = false
    this.inputWrapperTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  backToList() {
    this.inputTarget.disabled = true
    this.inputTarget.value = ""
    this.inputWrapperTarget.classList.add("hidden")
    this.selectTarget.disabled = false
    this.selectTarget.classList.remove("hidden")
    this.selectTarget.value = ""
  }
}
