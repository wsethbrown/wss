import { Controller } from "@hotwired/stimulus"

// Live search dropdown, three shapes:
//
// - Section mode (grouped: true), the /reviews page. Fetches the section
//   endpoint, which returns { bottles: [...], societies: [...] }; renders
//   grouped results. Deliberately NO "add a new bottle" row: a society name
//   or a typo must never become a junk catalog entry from here.
// - Picker mode (grouped: false, no bottleId target), the start-a-review
//   page. Fetches the bottle endpoint (a flat array); rows link to each
//   bottle's REVIEW form (review_url) and an explicit "+ Add …" escape
//   hatch is appended, because the intent to catalog is unambiguous there.
// - Fill mode (grouped: false, WITH a bottleId hidden-input target), the
//   event pour form. Clicking a row fills the hidden bottle_id instead of
//   navigating; the "+ Add …" escape carries return-to so the organizer
//   lands back on the event after cataloging.
// - Chip mode (fill mode + submitOnSelect + a customName target), the
//   account shelf editor. Picking a row submits the form immediately; the
//   add-row (label from addLabel, %s = the query) fills custom_name and
//   submits instead of navigating to /bottles/new — the shelf must never
//   become a side door into the catalog.
//
// - Name mode (fill mode + nameField), the deck pour form. There is ONE name
//   box: type free text to name an uncatalogued pour, or pick a suggestion to
//   link a catalog bottle. Picking fills the bare name (not "Name ·
//   Distillery"), prefills the row's origin/style, and shows the link state;
//   typing something else unlinks the row again.
//
// All rendering is textContent/createElement, user input never becomes HTML.
export default class extends Controller {
  static targets = ["input", "results", "bottleId", "customName", "linkState"]
  static values = {
    url: String,
    grouped: { type: Boolean, default: false },
    returnTo: { type: String, default: "" },
    submitOnSelect: { type: Boolean, default: false },
    addLabel: { type: String, default: "" },
    // Name mode (the deck pour form): the search box IS the name field, so it
    // takes the bottle's bare name rather than "Name · Distillery", and typing
    // something else unlinks the row. Off everywhere else.
    nameField: { type: Boolean, default: false }
  }

  query() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    // In name mode the box holds the linked bottle's name. Once it says
    // something else, the row is no longer that bottle.
    if (this.nameFieldValue && this.hasBottleIdTarget && q !== this.linkedName) this.unlink()
    if (q.length < 2) { this.resultsTarget.classList.add("hidden"); return }
    this.timer = setTimeout(() => this.fetch(q), 200)
  }

  async fetch(q) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
      headers: { Accept: "application/json" }
    })
    if (!response.ok) return
    const data = await response.json()
    this.groupedValue ? this.renderGroups(data) : this.renderPicker(data, q)
  }

  renderGroups(data) {
    this.resultsTarget.textContent = ""
    const groups = [["Distilleries", data.distilleries], ["Bottles", data.bottles], ["Societies", data.societies]]
    let any = false
    for (const [heading, items] of groups) {
      if (!items?.length) continue
      any = true
      this.resultsTarget.appendChild(this.heading(heading))
      for (const item of items) this.resultsTarget.appendChild(this.link(item.label, item.url))
    }
    if (!any) this.resultsTarget.appendChild(this.empty())
    this.resultsTarget.classList.remove("hidden")
  }

  renderPicker(matches, q) {
    this.resultsTarget.textContent = ""
    for (const match of matches) {
      if (this.hasBottleIdTarget) {
        this.resultsTarget.appendChild(this.fillRow(match))
      } else {
        this.resultsTarget.appendChild(this.link(match.display_name, match.review_url || match.url))
      }
    }
    const add = this.hasCustomNameTarget ? this.customNameRow(q) : this.catalogRow(q)
    add.classList.add("border-t", "border-gray-100", "font-medium", "text-whiskey-700")
    add.classList.remove("text-gray-800")
    this.resultsTarget.appendChild(add)
    this.resultsTarget.classList.remove("hidden")
  }

  catalogRow(q) {
    let addHref = `/bottles/new?name=${encodeURIComponent(q)}`
    if (this.returnToValue) addHref += `&return_to=${encodeURIComponent(this.returnToValue)}`
    return this.link(`+ Add "${q}" as a new bottle`, addHref)
  }

  customNameRow(q) {
    const label = (this.addLabelValue || `+ Add "%s"`).replace("%s", q)
    const el = document.createElement("button")
    el.type = "button"
    el.textContent = label
    el.className = "block w-full text-left px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    el.addEventListener("click", () => {
      this.bottleIdTarget.value = ""
      this.customNameTarget.value = q
      this.resultsTarget.classList.add("hidden")
      this.submitForm()
    })
    return el
  }

  fillRow(match) {
    const el = document.createElement("button")
    el.type = "button"
    el.textContent = match.display_name
    el.className = "block w-full text-left px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    el.addEventListener("click", () => {
      this.bottleIdTarget.value = match.id
      if (this.hasCustomNameTarget) this.customNameTarget.value = ""
      this.inputTarget.value = this.nameFieldValue ? match.name : match.display_name
      this.linkedName = this.inputTarget.value
      this.showLinked(match.display_name)
      this.resultsTarget.classList.add("hidden")
      this.autofill(match)
      if (this.submitOnSelectValue) this.submitForm()
    })
    return el
  }

  // The row's link state, shown rather than implied: an admin has to be able
  // to tell at a glance whether this pour earns the deck real scores.
  showLinked(label) {
    if (!this.hasLinkStateTarget) return
    this.linkStateTarget.textContent = `Linked to ${label}`
    this.linkStateTarget.classList.remove("hidden", "text-gray-400")
    this.linkStateTarget.classList.add("text-green-700")
  }

  unlink() {
    this.bottleIdTarget.value = ""
    this.linkedName = null
    if (!this.hasLinkStateTarget) return
    this.linkStateTarget.textContent = "Not linked to the catalog, so this pour earns no scores."
    this.linkStateTarget.classList.remove("text-green-700")
    this.linkStateTarget.classList.add("text-gray-400")
  }

  // Copy what the catalog already knows into any [data-bottle-fill] field in
  // scope, so an admin adding a bottle to a deck's pour list doesn't retype
  // its origin and style every time.
  //
  // EMPTY FIELDS ONLY. These are per-deck values the author may have already
  // written by hand, and silently overwriting someone's typing is worse than
  // making them fill in a blank. Filled values stay editable: the catalog is
  // the starting point, not the last word.
  autofill(match) {
    this.element.querySelectorAll("[data-bottle-fill]").forEach((field) => {
      if (field.value.trim() !== "") return

      const value = match[field.dataset.bottleFill]
      if (value) field.value = value
    })
  }

  // Pressing Enter in the search box (instead of picking a row) adds the
  // typed text as a free-text entry.
  fillFreeTextBeforeSubmit() {
    if (!this.hasCustomNameTarget) return
    if (this.bottleIdTarget.value === "") {
      this.customNameTarget.value = this.inputTarget.value.trim()
    }
  }

  submitForm() {
    this.inputTarget.form?.requestSubmit()
  }

  heading(text) {
    const el = document.createElement("p")
    el.textContent = text
    el.className = "eyebrow border-b border-gray-100 bg-gray-50 px-4 py-1.5 text-gray-400"
    return el
  }

  link(text, href) {
    const el = document.createElement("a")
    el.href = href
    el.textContent = text
    el.className = "block px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    return el
  }

  empty() {
    const el = document.createElement("p")
    el.textContent = "Nothing on the record yet."
    el.className = "px-4 py-2.5 text-sm text-gray-400"
    return el
  }

  connect() {
    // Remember what the box said when it arrived linked, so an untouched row
    // doesn't unlink itself on the first keystroke elsewhere.
    if (this.nameFieldValue && this.hasBottleIdTarget && this.bottleIdTarget.value) {
      this.linkedName = this.inputTarget.value.trim()
    }
  }

  disconnect() { clearTimeout(this.timer) }
}
