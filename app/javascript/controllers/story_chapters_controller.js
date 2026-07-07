import { Controller } from "@hotwired/stimulus"

// Chapter-based editor for the deck story.
//
// The story is stored as ONE Markdown string on presentation.content, with
// `## ` headings marking chapters. This controller presents that string as
// chapter cards (title + body each) and serializes every edit back into the
// hidden content field, so the server never learns a new format.
//
// The teaser marker shows where the buyer-page free preview cuts off: the
// first TEASER_LINES source lines. Keep in sync with
// PresentationsHelper#preview_markdown / #story_truncated?.
const TEASER_LINES = 24

export default class extends Controller {
  static targets = ["container", "template", "hidden", "raw", "rawWrapper",
                    "chaptersUi", "toggle", "marker"]

  connect() {
    this.renderFromMarkdown(this.hiddenTarget.value)
  }

  // ── chapters → cards ──────────────────────────────────────────────────
  renderFromMarkdown(markdown) {
    this.containerTarget.innerHTML = ""
    let chapters = this.parse(markdown)
    if (chapters.length === 0) chapters = [{ title: "", body: "" }]
    chapters.forEach(ch => this.appendCard(ch.title, ch.body))
    this.refresh()
  }

  parse(markdown) {
    const chapters = []
    let current = { title: "", body: [] }
    for (const line of (markdown || "").split("\n")) {
      const heading = line.match(/^##\s+(.*)$/)
      if (heading) {
        if (current.title !== "" || current.body.join("\n").trim() !== "") chapters.push(current)
        current = { title: heading[1].trim(), body: [] }
      } else {
        current.body.push(line)
      }
    }
    if (current.title !== "" || current.body.join("\n").trim() !== "") chapters.push(current)
    return chapters.map(ch => ({ title: ch.title, body: ch.body.join("\n").replace(/^\n+|\n+$/g, "") }))
  }

  appendCard(title, body) {
    const card = this.templateTarget.content.cloneNode(true)
    card.querySelector(".chapter-title").value = title
    const bodyField = card.querySelector(".chapter-body")
    bodyField.value = body
    bodyField.rows = Math.min(Math.max(body.split("\n").length + 1, 3), 16)
    this.containerTarget.appendChild(card)
  }

  // ── cards → markdown ──────────────────────────────────────────────────
  serializedParts() {
    const parts = []
    this.containerTarget.querySelectorAll(".chapter-item").forEach(item => {
      const title = item.querySelector(".chapter-title").value.trim()
      const body = item.querySelector(".chapter-body").value.replace(/^\n+|\n+$/g, "")
      if (title === "" && body === "") return
      if (title === "") parts.push(body)
      else parts.push(body === "" ? `## ${title}` : `## ${title}\n\n${body}`)
    })
    return parts
  }

  refresh() {
    const parts = this.serializedParts()
    this.hiddenTarget.value = parts.join("\n\n")
    this.renumber()
    this.placeTeaserMarker(parts)
  }

  renumber() {
    let n = 0
    this.containerTarget.querySelectorAll(".chapter-item").forEach((item, i) => {
      const titled = item.querySelector(".chapter-title").value.trim() !== ""
      const label = item.querySelector(".chapter-label")
      if (i === 0 && !titled) {
        label.textContent = "The opening"
      } else {
        n += 1
        label.textContent = `Chapter ${n}`
      }
    })
  }

  // The free teaser is the first TEASER_LINES source lines. Walk the
  // serialized parts and flag the card where the cut lands.
  placeTeaserMarker(parts) {
    if (this.hasMarkerTarget) this.markerTarget.remove()

    const items = Array.from(this.containerTarget.querySelectorAll(".chapter-item"))
    const nonEmpty = items.filter(item =>
      item.querySelector(".chapter-title").value.trim() !== "" ||
      item.querySelector(".chapter-body").value.trim() !== "")

    let lines = 0
    for (let i = 0; i < parts.length; i++) {
      if (i > 0) lines += 1 // the blank line joining parts
      lines += parts[i].split("\n").length
      if (lines > TEASER_LINES) {
        const marker = document.createElement("p")
        marker.dataset.storyChaptersTarget = "marker"
        marker.className = "flex items-center gap-3 text-xs font-semibold uppercase tracking-wide text-whiskey-700"
        const rule = () => {
          const span = document.createElement("span")
          span.className = "h-px flex-1 bg-whiskey-300"
          return span
        }
        marker.append(rule(), "The free teaser fades out here — everything below is buyers-only", rule())
        nonEmpty[i]?.after(marker)
        return
      }
    }
  }

  // ── card actions ──────────────────────────────────────────────────────
  fieldChanged() { this.refresh() }

  addChapter() {
    this.appendCard("", "")
    this.refresh()
    const cards = this.containerTarget.querySelectorAll(".chapter-item")
    cards[cards.length - 1].querySelector(".chapter-title").focus()
  }

  removeChapter(event) {
    event.target.closest(".chapter-item").remove()
    if (this.containerTarget.querySelectorAll(".chapter-item").length === 0) this.appendCard("", "")
    this.refresh()
  }

  // Siblings may include the teaser marker — skip anything that isn't a card.
  moveUp(event) {
    const item = event.target.closest(".chapter-item")
    let prev = item.previousElementSibling
    while (prev && !prev.classList.contains("chapter-item")) prev = prev.previousElementSibling
    if (prev) item.parentNode.insertBefore(item, prev)
    this.refresh()
  }

  moveDown(event) {
    const item = event.target.closest(".chapter-item")
    let next = item.nextElementSibling
    while (next && !next.classList.contains("chapter-item")) next = next.nextElementSibling
    if (next) item.parentNode.insertBefore(next, item)
    this.refresh()
  }

  // ── raw Markdown escape hatch ─────────────────────────────────────────
  toggleRaw() {
    const showingRaw = !this.rawWrapperTarget.classList.contains("hidden")
    if (showingRaw) {
      this.hiddenTarget.value = this.rawTarget.value
      this.renderFromMarkdown(this.rawTarget.value)
      this.rawWrapperTarget.classList.add("hidden")
      this.chaptersUiTarget.classList.remove("hidden")
      this.toggleTarget.textContent = "Edit as raw Markdown"
    } else {
      this.refresh()
      this.rawTarget.value = this.hiddenTarget.value
      this.rawTarget.rows = Math.min(Math.max(this.hiddenTarget.value.split("\n").length + 2, 10), 28)
      this.chaptersUiTarget.classList.add("hidden")
      this.rawWrapperTarget.classList.remove("hidden")
      this.toggleTarget.textContent = "Back to chapters"
    }
  }

  rawChanged() { this.hiddenTarget.value = this.rawTarget.value }
}
