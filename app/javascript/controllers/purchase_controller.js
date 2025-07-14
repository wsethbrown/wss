import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.modal = this.element
    
    // Listen for open events from other controllers
    document.addEventListener('purchase-modal:open', () => {
      this.open()
    })
  }

  open() {
    console.log('Opening modal...')
    this.modal.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  close() {
    console.log('Closing modal...')
    this.modal.classList.add('hidden')
    document.body.style.overflow = ''
  }

  // Close modal when clicking outside
  clickOutside(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}