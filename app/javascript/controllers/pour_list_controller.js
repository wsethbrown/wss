import { Controller } from "@hotwired/stimulus"

// The deck's pour list rows (section 6 of the admin deck form).
//
// Rows are nested attributes, so adding one is just cloning the template with
// a unique index and removing one is ticking _destroy: nothing here talks to
// the server. The deck's Save button persists the whole list, same as every
// other section of the form.
export default class extends Controller {
  static targets = ["container", "template", "row"]

  add(event) {
    event.preventDefault()
    // Index by timestamp so a row added, removed, and re-added can't collide
    // with an index Rails already used in this form.
    //
    // insertAdjacentHTML is an XSS sink in general. It's safe here and only
    // here: the source is a server-rendered <template> built from a blank
    // PresentationBottle (no record data, ERB-escaped), and the only value
    // substituted in is a timestamp. Never feed this a string containing
    // anything a user typed.
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", html)
    this.renumber()
    const added = this.rowTargets[this.rowTargets.length - 1]
    if (added) added.querySelector("input[type=search]")?.focus()
  }

  // A ticked row stays in the DOM (Rails needs the _destroy field submitted)
  // but reads as struck through so it's obvious what Save will do.
  toggleDestroy(event) {
    const row = event.target.closest(".pour-row")
    if (!row) return
    row.classList.toggle("opacity-50", event.target.checked)
    row.classList.toggle("line-through", event.target.checked)
  }

  // Position is what orders the list on the deck page, so it has to follow
  // the on-screen order rather than creation order.
  renumber() {
    this.rowTargets.forEach((row, i) => {
      const position = row.querySelector("input[name*='[position]']")
      if (position) position.value = i + 1
    })
  }
}
