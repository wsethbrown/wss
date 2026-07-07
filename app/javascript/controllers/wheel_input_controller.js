import { Controller } from "@hotwired/stimulus"

// The tasting wheel as an input: press anywhere in a segment and drag
// outward — further from the hub means stronger. Drag back into the hub to
// clear a family. No modes, no instructions; the gesture is the meaning.
const R = 96
const HUB = 22

export default class extends Controller {
  static targets = ["svg", "fill", "label", "input"]

  connect() {
    this.families = this.fillTargets.map(el => el.dataset.family)
    this.step = 360 / this.families.length
    this.dragging = false
    this.paintAll()
  }

  down(event) { this.dragging = true; this.apply(event) }
  move(event) { if (this.dragging) this.apply(event) }
  up() { this.dragging = false }

  apply(event) {
    event.preventDefault()
    const rect = this.svgTarget.getBoundingClientRect()
    const scale = 220 / rect.width
    const x = (event.clientX - rect.left) * scale - 110
    const y = (event.clientY - rect.top) * scale - 110
    const dist = Math.hypot(x, y)
    if (dist > R + 8) return
    let deg = (Math.atan2(y, x) * 180) / Math.PI + 90 // 0 at top
    if (deg < 0) deg += 360
    const family = this.families[Math.floor(deg / this.step) % this.families.length]
    const intensity = dist <= HUB ? 0 : Math.min(1, Math.round(((dist - HUB) / (R - HUB)) * 20) / 20)
    this.set(family, intensity)
  }

  set(family, intensity) {
    const input = this.inputTargets.find(i => i.dataset.family === family)
    input.value = intensity
    this.paint(family)
  }

  paintAll() { this.families.forEach(f => this.paint(f)) }

  paint(family) {
    const i = this.families.indexOf(family)
    const value = parseFloat(this.inputTargets.find(el => el.dataset.family === family).value) || 0
    const fill = this.fillTargets[i]
    const label = this.labelTargets[i]
    const r = HUB + (R - HUB) * value
    fill.setAttribute("d", value > 0 ? this.sector(i, r) : "")
    label.style.fontWeight = value > 0 ? "700" : "500"
    label.style.fillOpacity = value > 0 ? "1" : "0.5"
  }

  sector(i, r) {
    const a0 = ((-90 + i * this.step) * Math.PI) / 180
    const a1 = ((-90 + (i + 1) * this.step) * Math.PI) / 180
    const p = (a, rad) => `${(rad * Math.cos(a)).toFixed(1)},${(rad * Math.sin(a)).toFixed(1)}`
    return `M${p(a0, HUB)} L${p(a0, r)} A${r},${r} 0 0 1 ${p(a1, r)} L${p(a1, HUB)} A${HUB},${HUB} 0 0 0 ${p(a0, HUB)} Z`
  }
}
