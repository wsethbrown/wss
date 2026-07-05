import { Controller } from "@hotwired/stimulus"

// Structured editor for the slide-by-slide preview. Rows of title /
// description / duration; the slide number comes from row order — admins
// never type "Slide 3". Serializes to the legacy pipe format the public
// page already parses (Presentation#parsed_slides_preview):
//   Slide 1|Title|Description|5 min
export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    const existingData = document.getElementById("existing-slides-preview")
    if (existingData && existingData.value.trim()) {
      this.loadExistingData(existingData.value)
    } else {
      this.addSlide()
    }
    this.updateHiddenField()
  }

  loadExistingData(data) {
    data.split("\n").forEach(line => {
      const parts = line.split("|")
      if (parts.length < 4) return

      this.addSlide()
      const rows = this.rows()
      const row = rows[rows.length - 1]
      // parts[0] is the stored "Slide N" label — regenerated from order.
      row.querySelector(".slide-title").value = parts[1].trim()
      row.querySelector(".slide-description").value = parts[2].trim()
      row.querySelector(".slide-duration").value = parts[3].trim()
    })

    if (this.rows().length === 0) this.addSlide()
    this.renumber()
  }

  addSlide(event) {
    if (event) event.preventDefault()
    const template = this.templateTarget.content.cloneNode(true)
    this.containerTarget.appendChild(template)
    this.renumber()
    this.updateHiddenField()
  }

  removeSlide(event) {
    event.preventDefault()
    event.target.closest(".slide-item").remove()
    if (this.rows().length === 0) this.addSlide()
    this.renumber()
    this.updateHiddenField()
  }

  moveUp(event) {
    event.preventDefault()
    const row = event.target.closest(".slide-item")
    const prev = row.previousElementSibling
    if (prev) row.parentNode.insertBefore(row, prev)
    this.renumber()
    this.updateHiddenField()
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.target.closest(".slide-item")
    const next = row.nextElementSibling
    if (next) row.parentNode.insertBefore(next, row)
    this.renumber()
    this.updateHiddenField()
  }

  fieldChanged() {
    this.updateHiddenField()
  }

  rows() {
    return Array.from(this.containerTarget.querySelectorAll(".slide-item"))
  }

  renumber() {
    this.rows().forEach((row, index) => {
      row.querySelector(".slide-number").textContent = `Slide ${index + 1}`
    })
  }

  updateHiddenField() {
    const lines = []
    this.rows().forEach((row, index) => {
      const title = row.querySelector(".slide-title").value.trim()
      const description = row.querySelector(".slide-description").value.trim()
      const duration = row.querySelector(".slide-duration").value.trim()

      if (title || description) {
        lines.push(`Slide ${index + 1}|${title}|${description}|${duration}`)
      }
    })

    const hiddenField = document.getElementById("slides_preview_hidden")
    if (hiddenField) hiddenField.value = lines.join("\n")
  }
}
