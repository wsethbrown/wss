import { Controller } from "@hotwired/stimulus"

// The Listing tab's "Extra sections" cards (admin/presentations/_sections_fields).
//
// Each card is two ordinary form fields, presentation[sections][][heading]
// and [lines], rendered by the server, so existing sections save without
// JavaScript and the order on the page is the order saved. This controller
// only adds a card (from the template), removes one, and moves one up or
// down. Each of those is an edit, so it announces itself with an "input"
// event: the unsaved-changes guard marks the form dirty and the customer
// preview refreshes, exactly as typing does.
export default class extends Controller {
  static targets = ["container", "template", "item"]

  add() {
    // Unique ids, so each card's label still points at its own field.
    const index = `new${Date.now()}${Math.floor(Math.random() * 1000)}`
    const fragment = this.templateTarget.content.cloneNode(true)
    fragment.querySelectorAll("[id], label[for]").forEach(node => {
      if (node.id) node.id = node.id.replace("NEW_SECTION", index)
      if (node.htmlFor) node.htmlFor = node.htmlFor.replace("NEW_SECTION", index)
    })
    this.containerTarget.appendChild(fragment)
    const card = this.containerTarget.lastElementChild
    card.querySelector(".section-heading")?.focus()
    this.changed(card)
  }

  remove(event) {
    const card = event.target.closest(".section-item")
    if (!card) return
    const neighbour = card.nextElementSibling || card.previousElementSibling
    card.remove()
    this.changed(neighbour || this.containerTarget)
  }

  moveUp(event) {
    const card = event.target.closest(".section-item")
    const previous = card?.previousElementSibling
    if (!previous) return
    card.parentNode.insertBefore(card, previous)
    event.target.closest("button")?.focus()
    this.changed(card)
  }

  moveDown(event) {
    const card = event.target.closest(".section-item")
    const next = card?.nextElementSibling
    if (!next) return
    card.parentNode.insertBefore(next, card)
    event.target.closest("button")?.focus()
    this.changed(card)
  }

  changed(from) {
    from.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
