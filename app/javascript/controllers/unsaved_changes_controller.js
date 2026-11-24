import { Controller } from "@hotwired/stimulus"

// Guards the admin deck form (#deck-form) against losing unsaved edits.
// Put it on the <form>. It starts dirty when the server re-rendered the form
// with errors (the fields then hold values that were never saved).
//
// Turbo stays on throughout, so every form keeps its own data-turbo-confirm
// (Delete, Unpublish). How each way off the page is guarded:
//
//   - A real unload (closing the tab, typing a URL, reload): the browser's own
//     leave prompt, via beforeunload.
//   - A Turbo link visit: cancelled and redone as a normal page load, so the
//     browser's own leave prompt asks.
//   - Another form on the page (Publish, Re-render, Unpublish, Delete): a form
//     with its own data-turbo-confirm asks only that (Turbo asks it; once the
//     admin says yes the edits are let go), a form without one asks
//     CONFIRM_MESSAGE first.
//   - Back and forward are NOT guarded. They are Turbo restoration visits,
//     which fire no before-visit, and holding their render
//     (turbo:before-render) without resuming it froze every later Turbo
//     render on the page (Save, errors, Publish). Losing edits on Back is the
//     lesser harm; do not reintroduce that hold.
//
// Saving this form clears the flag, so Save never prompts.
const CONFIRM_MESSAGE = "Your changes to this deck are not saved. Continue without saving them?"

export default class extends Controller {
  static values = { dirty: Boolean }

  connect() {
    this.onBeforeUnload = this.onBeforeUnload.bind(this)
    this.onBeforeVisit = this.onBeforeVisit.bind(this)
    this.onSubmitCapture = this.onSubmitCapture.bind(this)
    this.onSubmitStart = this.onSubmitStart.bind(this)

    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    document.addEventListener("submit", this.onSubmitCapture, true)
    document.addEventListener("turbo:submit-start", this.onSubmitStart)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    document.removeEventListener("submit", this.onSubmitCapture, true)
    document.removeEventListener("turbo:submit-start", this.onSubmitStart)
  }

  // ── what counts as an edit ────────────────────────────────────────────
  changed(event) {
    // "Find in the script" (a search box) and the tab tracker are not edits.
    // Unnamed fields are: the story and takeaway cards write into hidden
    // fields from fields of their own.
    const field = event.target
    if (!field || field.type === "search" || field.name === "tab") return
    this.dirtyValue = true
  }

  saving() {
    this.dirtyValue = false
  }

  // ── real unloads ──────────────────────────────────────────────────────
  onBeforeUnload(event) {
    if (!this.dirtyValue) return
    event.preventDefault()
    event.returnValue = ""
  }

  // ── Turbo link visits: become a normal load, so the browser asks ──────
  onBeforeVisit(event) {
    if (!this.dirtyValue) return
    event.preventDefault()
    window.location.assign(event.detail.url)
  }

  // ── other forms on the page ───────────────────────────────────────────
  onSubmitCapture(event) {
    const form = event.target
    if (!this.dirtyValue || form === this.element || !(form instanceof HTMLFormElement)) return
    if (this.hasOwnConfirm(form, event.submitter)) return // Turbo asks it; see onSubmitStart

    if (window.confirm(CONFIRM_MESSAGE)) {
      this.dirtyValue = false
    } else {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }

  // Turbo fires this only once a form's own confirmation was answered yes.
  onSubmitStart(event) {
    if (event.target !== this.element) this.dirtyValue = false
  }

  hasOwnConfirm(form, submitter) {
    return Boolean(submitter?.hasAttribute("data-turbo-confirm") || form.hasAttribute("data-turbo-confirm"))
  }
}
