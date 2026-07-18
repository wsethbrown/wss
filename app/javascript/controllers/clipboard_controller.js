import { Controller } from "@hotwired/stimulus"

// Click-to-copy for share links (the society invite link): copies the
// field's value and flashes a small toast above it. Falls back to
// select-and-copy where the async clipboard API is unavailable.
export default class extends Controller {
  static targets = ["source", "toast"]

  copy() {
    const text = this.sourceTarget.value
    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(() => this.flash()).catch(() => this.fallbackCopy())
    } else {
      this.fallbackCopy()
    }
  }

  fallbackCopy() {
    this.sourceTarget.select()
    document.execCommand("copy")
    this.flash()
  }

  flash() {
    this.toastTarget.classList.remove("hidden")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.toastTarget.classList.add("hidden"), 2000)
  }
}
