import { Controller } from "@hotwired/stimulus"

// Cloudflare Turnstile on the public sign-up forms (AuthHelper#turnstile_widget).
// Cloudflare's script is loaded once per page life and the widget is rendered
// explicitly here, so a Turbo visit back to the page renders a fresh widget
// instead of loading the script a second time. The widget writes its token to
// a hidden `cf-turnstile-response` field inside this element (inside the form).
const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let loading = null

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile)
  if (!loading) {
    loading = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = SCRIPT_URL
      script.async = true
      const nonce = document.querySelector('meta[name="csp-nonce"]')?.content
      if (nonce) script.nonce = nonce
      script.onload = () => resolve(window.turnstile)
      script.onerror = () => { loading = null; reject(new Error("Turnstile script failed to load")) }
      document.head.appendChild(script)
    })
  }
  return loading
}

export default class extends Controller {
  static values = { sitekey: String }

  async connect() {
    // A Turbo snapshot may carry a stale widget's markup; start clean.
    this.element.innerHTML = ""
    try {
      const turnstile = await loadTurnstile()
      if (!this.element.isConnected || this.widgetId !== undefined) return
      this.widgetId = turnstile.render(this.element, { sitekey: this.sitekeyValue })
    } catch (error) {
      console.warn(error.message)
    }
  }

  disconnect() {
    if (this.widgetId !== undefined && window.turnstile) window.turnstile.remove(this.widgetId)
    this.widgetId = undefined
  }
}
