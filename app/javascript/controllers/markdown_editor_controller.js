import { Controller } from "@hotwired/stimulus"
import EasyMDE from "easymde"

// Wraps the deck-story textarea in EasyMDE. Preview is rendered SERVER-side
// through the same render_markdown pipeline buyers see, so preview == reality.
export default class extends Controller {
  static values = { previewUrl: String }

  connect() {
    this.editor = new EasyMDE({
      element: this.element,
      spellChecker: false,
      status: ["lines", "words"],
      toolbar: ["bold", "italic", "heading-2", "heading-3", "|",
                "quote", "unordered-list", "ordered-list", "|",
                "link", "horizontal-rule", "|", "preview", "side-by-side", "fullscreen"],
      previewRender: (text, previewEl) => {
        this.renderServerPreview(text, previewEl)
        return "<p style='color:#999'>Rendering…</p>"
      }
    })
  }

  async renderServerPreview(text, previewEl) {
    const token = document.querySelector('meta[name="csrf-token"]').content
    const res = await fetch(this.previewUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ content: text })
    })
    previewEl.innerHTML = res.ok ? await res.text() : "<p>Preview failed.</p>"
    previewEl.classList.add("prose-deck")
  }

  disconnect() {
    this.editor?.toTextArea()
    this.editor = null
  }
}
