import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "searchInput", "zipInput", "rangeSelect", "publicToggle", "locationButton"]

  connect() {
    this.isUsingGeolocation = false
  }

  useCurrentLocation() {
    if (!navigator.geolocation) {
      this.showLocationError("Geolocation is not supported by this browser.")
      return
    }

    // Update button state
    this.locationButtonTarget.disabled = true
    this.locationButtonTarget.innerHTML = `
      <svg class="w-5 h-5 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
      </svg>
      <span>Getting Location...</span>
    `

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.handleLocationSuccess(position)
      },
      (error) => {
        this.handleLocationError(error)
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 60000
      }
    )
  }

  async handleLocationSuccess(position) {
    const { latitude, longitude } = position.coords
    
    try {
      // Use reverse geocoding to get zip code from coordinates
      const zipCode = await this.reverseGeocode(latitude, longitude)
      
      if (zipCode) {
        this.zipInputTarget.value = zipCode
        this.isUsingGeolocation = true
        this.showLocationSuccess("Location found! ZIP code updated.")
      } else {
        this.showLocationError("Could not determine ZIP code from your location.")
      }
    } catch (error) {
      this.showLocationError("Failed to get location details.")
    }
    
    this.resetLocationButton()
  }

  handleLocationError(error) {
    let message = "Unable to get your location."
    
    switch (error.code) {
      case error.PERMISSION_DENIED:
        message = "Location access denied by user."
        break
      case error.POSITION_UNAVAILABLE:
        message = "Location information unavailable."
        break
      case error.TIMEOUT:
        message = "Location request timed out."
        break
    }
    
    this.showLocationError(message)
    this.resetLocationButton()
  }

  async reverseGeocode(latitude, longitude) {
    try {
      // Using a free geocoding service (you might want to use Google Maps API in production)
      const response = await fetch(
        `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${latitude}&longitude=${longitude}&localityLanguage=en`
      )
      
      if (response.ok) {
        const data = await response.json()
        return data.postcode || null
      }
    } catch (error) {
      console.error("Reverse geocoding failed:", error)
    }
    
    return null
  }

  showLocationSuccess(message) {
    this.showMessage(message, "success")
  }

  showLocationError(message) {
    this.showMessage(message, "error")
  }

  showMessage(message, type) {
    // Create and show a temporary message
    const messageEl = document.createElement("div")
    messageEl.className = `fixed top-4 right-4 px-4 py-2 rounded-lg text-white z-50 ${
      type === "success" ? "bg-green-600" : "bg-red-600"
    }`
    messageEl.textContent = message
    
    document.body.appendChild(messageEl)
    
    // Remove message after 3 seconds
    setTimeout(() => {
      if (messageEl.parentNode) {
        messageEl.parentNode.removeChild(messageEl)
      }
    }, 3000)
  }

  resetLocationButton() {
    this.locationButtonTarget.disabled = false
    this.locationButtonTarget.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
      </svg>
      <span>Use My Location</span>
    `
  }

  clear() {
    // Clear all form fields
    this.searchInputTarget.value = ''
    this.zipInputTarget.value = ''
    this.rangeSelectTarget.selectedIndex = 2 // Reset to 25 miles default
    this.publicToggleTarget.checked = false
    this.isUsingGeolocation = false

    // Redirect to clean URL
    window.location.href = window.location.pathname
  }
}