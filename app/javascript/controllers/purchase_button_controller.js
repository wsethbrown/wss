import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  openModal() {
    console.log('Purchase button clicked...')
    document.dispatchEvent(new CustomEvent('purchase-modal:open'))
  }
}