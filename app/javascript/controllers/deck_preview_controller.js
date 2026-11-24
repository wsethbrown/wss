import { Controller } from "@hotwired/stimulus"

// "What the customer sees" on the admin deck page's Listing tab (and the
// new-deck form): keeps the preview frame in step with the fields.
//
// About 400ms after the last edit it posts the form's fields to the preview
// action (Admin::PresentationsController#preview), which renders the deck
// page's own partials from them without saving anything, and swaps the
// result into the frame's #customer-view. Files are never sent, and the
// form's _method is dropped so the request stays a POST.
//
// This is a fetch, not a form submission: Turbo and the unsaved-changes
// guard never see it, so it neither marks the form clean nor dirty.
//
// The frame (see _preview_document) is a sandboxed document with no scripts
// of its own; its height follows its content, so the page scrolls, not the
// frame.
const DELAY = 400

export default class extends Controller {
  static targets = ["frame", "status"]
  static values = { url: String }

  connect() {
    this.onResize = () => this.resize()
    window.addEventListener("resize", this.onResize)
    this.resize()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
    window.removeEventListener("resize", this.onResize)
  }

  // input/change on any field, and clicks on the editors' buttons (add,
  // remove and move a takeaway or a chapter change the hidden fields without
  // an input event).
  schedule(event) {
    if (event?.type === "click" && !event.target.closest("button")) return
    if (event?.target?.type === "file" || event?.target?.type === "search") return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refresh(), DELAY)
  }

  async refresh() {
    const form = this.element.closest("form")
    if (!form || !this.urlValue) return

    const body = new FormData()
    for (const [key, value] of new FormData(form)) {
      if (value instanceof File || key === "_method") continue
      body.append(key, value)
    }

    this.request?.abort()
    const request = (this.request = new AbortController())
    // The frame is being updated: aria-busy says so to assistive technology,
    // as Turbo does for its own requests (the system tests wait on it too).
    this.frameTarget.setAttribute("aria-busy", "true")
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body,
        headers: { Accept: "text/html", "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin",
        signal: request.signal
      })
      // A redirect means the request was refused (signed out, or an expired
      // session): its page is not a preview, so it is never shown as one.
      if (!response.ok || response.redirected) {
        throw new Error(`preview answered ${response.status}${response.redirected ? " after a redirect" : ""}`)
      }
      const html = await response.text()
      if (request !== this.request) return
      this.show(html)
      if (this.hasStatusTarget) this.statusTarget.hidden = true
    } catch (error) {
      if (error.name === "AbortError") return
      if (this.hasStatusTarget) this.statusTarget.hidden = false
      console.warn("Customer preview not updated:", error.message)
    } finally {
      if (request === this.request) this.frameTarget.removeAttribute("aria-busy")
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  get root() {
    return this.frameTarget.contentDocument?.getElementById("customer-view")
  }

  // The HTML is the server's render of the deck page partials (escaped
  // there), going into a frame that cannot run scripts.
  show(html) {
    const root = this.root
    if (!root) {
      this.pending = html // the frame is still loading; frameLoaded applies it
      return
    }
    root.innerHTML = html
    this.resize()
  }

  frameLoaded() {
    if (this.pending !== undefined) {
      const html = this.pending
      this.pending = undefined
      this.show(html)
    } else {
      this.resize()
    }
  }

  resize() {
    const root = this.root
    if (!root || this.frameTarget.offsetWidth === 0) return // a hidden tab has no width to measure
    root.querySelectorAll("img").forEach(img => {
      if (!img.complete) img.addEventListener("load", () => this.resize(), { once: true })
    })
    this.frameTarget.style.height = `${Math.ceil(root.getBoundingClientRect().height)}px`
  }
}
