import { Controller } from "@hotwired/stimulus"

// The Slides and script tab of the admin deck page.
//
// Server-rendered: every slide's thumbnail (a link to its large image), one
// large slide, and the script for each slide as sanitised HTML. Without
// JavaScript the first slide shows large and every script is listed. This
// controller makes it a viewer: one slide and its script at a time,
// ← Previous / Next →, the left and right arrow keys (not while typing in a
// field, and only while this tab is showing), the "free" marks following the
// free preview number, and "Find in the script".
//
// Find never builds HTML from what was typed: it hides and dims elements and
// wraps matching text nodes in <mark>, so the script stays the server's
// sanitised markup.
export default class extends Controller {
  static targets = ["thumb", "stage", "position", "controls", "script", "notes",
                    "badge", "free", "findBox", "query", "hits"]
  static values = { total: Number }

  connect() {
    if (!this.hasStageTarget) return
    this.index = 0
    this.query = ""
    if (this.hasControlsTarget) {
      this.controlsTarget.classList.remove("hidden")
      this.controlsTarget.classList.add("flex")
    }
    if (this.hasFindBoxTarget) {
      this.findBoxTarget.classList.remove("hidden")
      this.findBoxTarget.classList.add("flex")
    }
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    this.go(0, { scroll: false })
  }

  disconnect() {
    if (this.onKeydown) document.removeEventListener("keydown", this.onKeydown)
  }

  // ── stepping ──────────────────────────────────────────────────────────
  pick(event) {
    event.preventDefault()
    this.go(Number(event.currentTarget.dataset.index))
  }

  previous() { this.go(this.index - 1) }
  next() { this.go(this.index + 1) }

  go(index, { scroll = true } = {}) {
    const total = this.thumbTargets.length
    if (total === 0) return
    this.index = Math.max(0, Math.min(total - 1, index))
    const thumb = this.thumbTargets[this.index]

    this.stageTarget.src = thumb.dataset.heroUrl
    this.stageTarget.alt = thumb.getAttribute("aria-label") || `Slide ${this.index + 1}`
    if (this.hasPositionTarget) this.positionTarget.textContent = `Slide ${this.index + 1} of ${total}`

    this.thumbTargets.forEach((t, i) => t.setAttribute("aria-current", i === this.index ? "true" : "false"))
    this.scriptTargets.forEach(s => { s.hidden = Number(s.dataset.index) !== this.index })
    if (this.hasNotesTarget) this.notesTarget.scrollTop = 0

    if (scroll) thumb.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  onKeydown(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
    if (this.element.offsetParent === null) return // this tab isn't showing
    const active = document.activeElement
    if (active && (active.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(active.tagName))) return

    event.preventDefault()
    event.key === "ArrowRight" ? this.next() : this.previous()
  }

  // ── free preview marks ────────────────────────────────────────────────
  // Mirrors Presentation#effective_preview_slide_count: never the whole deck.
  freeChanged() {
    const total = this.thumbTargets.length
    let free = parseInt(this.freeTarget.value, 10) || 0
    if (total <= 1) free = total
    else free = Math.max(1, Math.min(free, total - 1))
    this.badgeTargets.forEach((badge, i) => { badge.hidden = i >= free })
  }

  // ── find in the script ────────────────────────────────────────────────
  queryKeydown(event) {
    // Enter in the search box must not submit the deck form.
    if (event.key === "Enter") event.preventDefault()
  }

  find() {
    this.query = this.queryTarget.value.trim()
    const needle = this.query.toLowerCase()
    const matches = new Set()

    this.scriptTargets.forEach(script => {
      this.unmark(script)
      const index = Number(script.dataset.index)
      if (needle && script.textContent.toLowerCase().includes(needle)) {
        matches.add(index)
        this.mark(script, needle)
      }
    })

    this.thumbTargets.forEach((thumb, i) => {
      thumb.classList.toggle("opacity-25", needle !== "" && !matches.has(i))
    })

    const total = this.thumbTargets.length
    this.hitsTarget.textContent = !needle ? "" :
      matches.size ? `${matches.size} of ${total} slides` : "No slide mentions that"

    if (needle && matches.size && !matches.has(this.index)) {
      this.go(Math.min(...matches))
    }
  }

  // Wrap each case-insensitive occurrence of needle in this element's text
  // nodes in a <mark>. Text only: no HTML is parsed or built from the query.
  mark(root, needle) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
    const nodes = []
    while (walker.nextNode()) nodes.push(walker.currentNode)

    nodes.forEach(node => {
      const text = node.nodeValue
      const lower = text.toLowerCase()
      let at = lower.indexOf(needle)
      if (at === -1) return

      const fragment = document.createDocumentFragment()
      let from = 0
      while (at !== -1) {
        if (at > from) fragment.append(text.slice(from, at))
        const mark = document.createElement("mark")
        mark.className = "rounded bg-whiskey-200 px-0.5 text-ink"
        mark.textContent = text.slice(at, at + needle.length)
        fragment.append(mark)
        from = at + needle.length
        at = lower.indexOf(needle, from)
      }
      if (from < text.length) fragment.append(text.slice(from))
      node.replaceWith(fragment)
    })
  }

  unmark(root) {
    root.querySelectorAll("mark").forEach(mark => mark.replaceWith(document.createTextNode(mark.textContent)))
    root.normalize()
  }
}
