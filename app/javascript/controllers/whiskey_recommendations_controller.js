import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    // Parse existing recommendations if editing
    this.parseExistingRecommendations()
  }

  parseExistingRecommendations() {
    const existingValue = this.element.querySelector('#existing-recommendations')?.value
    if (existingValue && existingValue.trim() !== '') {
      const recommendations = existingValue.split('\n').filter(line => line.trim() !== '')
      
      recommendations.forEach(recommendation => {
        const parts = recommendation.split('|')
        if (parts.length >= 4) {
          this.addRecommendation({
            name: parts[0].trim(),
            region: parts[1].trim(),
            price: parts[2].trim(),
            style: parts[3].trim(),
            notes: parts[4]?.trim() || ''
          })
        }
      })
    } else {
      // Add one empty recommendation field by default
      this.addRecommendation()
    }
  }

  addRecommendation(data = {}) {
    const template = this.templateTarget.content.cloneNode(true)
    const container = template.querySelector('.recommendation-item')
    
    // Generate unique IDs for form fields
    const timestamp = Date.now()
    const random = Math.random().toString(36).substring(2, 9)
    const uniqueId = `${timestamp}-${random}`
    
    // Set values if provided (for existing recommendations)
    if (data.name) {
      template.querySelector('.whiskey-name').value = data.name
    }
    if (data.region) {
      template.querySelector('.whiskey-region').value = data.region
    }
    if (data.price) {
      template.querySelector('.whiskey-price').value = data.price
    }
    if (data.style) {
      template.querySelector('.whiskey-style').value = data.style
    }
    if (data.notes) {
      template.querySelector('.whiskey-notes').value = data.notes
    }
    
    // Update field names to be unique
    template.querySelectorAll('input, select').forEach(field => {
      if (field.name) {
        field.name = field.name.replace('[INDEX]', `[${uniqueId}]`)
      }
    })
    
    this.containerTarget.appendChild(template)
    this.updateRecommendationsField()
  }

  removeRecommendation(event) {
    event.preventDefault()
    const item = event.target.closest('.recommendation-item')
    item.remove()
    this.updateRecommendationsField()
  }

  updateRecommendationsField() {
    const recommendations = []
    const items = this.containerTarget.querySelectorAll('.recommendation-item')
    
    items.forEach(item => {
      const name = item.querySelector('.whiskey-name').value.trim()
      const region = item.querySelector('.whiskey-region').value.trim()
      const price = item.querySelector('.whiskey-price').value.trim()
      const style = item.querySelector('.whiskey-style').value.trim()
      const notes = item.querySelector('.whiskey-notes').value.trim()
      
      if (name || region || price || style || notes) {
        recommendations.push(`${name}|${region}|${price}|${style}|${notes}`)
      }
    })
    
    // Update the hidden field that will be submitted
    const hiddenField = this.element.querySelector('#whiskey_recommendations_hidden')
    if (hiddenField) {
      hiddenField.value = recommendations.join('\n')
    }
  }

  // Called when any field changes
  fieldChanged() {
    this.updateRecommendationsField()
  }
}