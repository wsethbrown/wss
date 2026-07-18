import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

// The event date/time fields (owner-approved July 2026): flatpickr replaces
// the cramped native datetime-local widget. The hidden submitted value keeps
// the datetime-local wire format (Y-m-dTH:i) so the server's parsing is
// untouched; the visible altInput shows an editorial "Jul 25, 2026 at 7:00 PM".
// Picking a start when the end is empty (or now behind the start) sets the
// end to the same day, three hours later.
export default class extends Controller {
  static targets = ["start", "end"]

  connect() {
    const base = {
      enableTime: true,
      dateFormat: "Y-m-d\\TH:i",
      altInput: true,
      altFormat: "M j, Y at h:i K",
      minuteIncrement: 15,
      altInputClass: "w-full rounded-lg border border-gray-300 px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-whiskey-500"
    }
    this.endPicker = flatpickr(this.endTarget, base)
    this.startPicker = flatpickr(this.startTarget, {
      ...base,
      onChange: (dates) => this.syncEnd(dates)
    })
  }

  disconnect() {
    this.startPicker?.destroy()
    this.endPicker?.destroy()
  }

  syncEnd(dates) {
    const start = dates[0]
    if (!start) return
    const end = this.endPicker.selectedDates[0]
    if (!end || end <= start) {
      this.endPicker.setDate(new Date(start.getTime() + 3 * 60 * 60 * 1000), false)
    }
  }
}
