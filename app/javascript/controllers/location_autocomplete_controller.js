import { Controller } from "@hotwired/stimulus"

// Google Places autocomplete on plain-text location inputs (events and
// societies). Progressive enhancement: no key in the page (or an API
// failure) leaves a normal text field. The chosen suggestion is written
// back as plain text, so the server keeps storing a string.
let mapsLoader = null

function loadMaps(key) {
  if (window.google?.maps?.places) return Promise.resolve()
  if (mapsLoader) return mapsLoader
  mapsLoader = new Promise((resolve, reject) => {
    window._wssMapsReady = () => resolve()
    const script = document.createElement("script")
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(key)}&libraries=places&loading=async&callback=_wssMapsReady`
    script.async = true
    script.onerror = reject
    document.head.appendChild(script)
  })
  return mapsLoader
}

export default class extends Controller {
  async connect() {
    const key = document.querySelector('meta[name="google-maps-key"]')?.content
    if (!key) return

    try {
      await loadMaps(key)
    } catch {
      return // the field stays a plain input
    }

    this.autocomplete = new google.maps.places.Autocomplete(this.element, {
      fields: ["name", "formatted_address"]
    })
    this.autocomplete.addListener("place_changed", () => {
      const place = this.autocomplete.getPlace()
      if (!place) return
      const address = place.formatted_address || ""
      const name = place.name || ""
      // Venues read "Creature Comforts, 271 W Hancock Ave..."; addresses
      // stand alone (the name would just repeat the street number).
      this.element.value = name && !address.startsWith(name) ? [name, address].filter(Boolean).join(", ") : (address || name)
    })
  }
}
