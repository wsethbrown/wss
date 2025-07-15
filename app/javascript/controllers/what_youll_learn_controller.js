import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    // Load existing data if any
    const existingData = document.getElementById('existing-what-youll-learn')
    if (existingData && existingData.value) {
      this.loadExistingData(existingData.value)
    } else {
      // Add one empty item by default
      this.addLearningPoint()
    }
    
    // Update hidden field on page load
    this.updateHiddenField()
  }

  loadExistingData(data) {
    // Parse the existing format
    const sections = []
    let currentTitle = null
    let currentDescription = []
    let inSection = false
    
    data.split('\n').forEach(line => {
      if (line.trim().match(/^[-•*]\s*(.+)$/)) {
        if (currentTitle && inSection) {
          sections.push({
            title: currentTitle,
            description: currentDescription.join(' ').trim()
          })
        }
        currentTitle = line.trim().replace(/^[-•*]\s*/, '')
        currentDescription = []
        inSection = true
      } else if (line.trim() === '') {
        if (inSection && currentDescription.length > 0) {
          sections.push({
            title: currentTitle,
            description: currentDescription.join(' ').trim()
          })
          currentTitle = null
          currentDescription = []
          inSection = false
        }
      } else if (inSection) {
        currentDescription.push(line.trim())
      }
    })
    
    if (currentTitle && inSection) {
      sections.push({
        title: currentTitle,
        description: currentDescription.join(' ').trim()
      })
    }
    
    // Create form fields for each section
    sections.forEach(section => {
      this.addLearningPoint()
      const items = this.containerTarget.querySelectorAll('.learning-point-item')
      const lastItem = items[items.length - 1]
      
      lastItem.querySelector('.learning-title').value = section.title
      lastItem.querySelector('.learning-description').value = section.description
    })
    
    // If no sections were found, add an empty one
    if (sections.length === 0) {
      this.addLearningPoint()
    }
  }

  addLearningPoint(event) {
    if (event) event.preventDefault()
    
    const template = this.templateTarget.content.cloneNode(true)
    this.containerTarget.appendChild(template)
    
    // Update hidden field
    this.updateHiddenField()
  }

  removeLearningPoint(event) {
    event.preventDefault()
    const item = event.target.closest('.learning-point-item')
    item.remove()
    
    // Ensure at least one item remains
    if (this.containerTarget.querySelectorAll('.learning-point-item').length === 0) {
      this.addLearningPoint()
    }
    
    // Update hidden field
    this.updateHiddenField()
  }

  fieldChanged() {
    this.updateHiddenField()
  }

  updateHiddenField() {
    const items = this.containerTarget.querySelectorAll('.learning-point-item')
    const sections = []
    
    items.forEach(item => {
      const title = item.querySelector('.learning-title').value.trim()
      const description = item.querySelector('.learning-description').value.trim()
      
      if (title || description) {
        sections.push(`- ${title}\n${description}`)
      }
    })
    
    // Update the hidden field with formatted text
    const hiddenField = document.getElementById('what_youll_learn_hidden')
    if (hiddenField) {
      hiddenField.value = sections.join('\n\n')
    }
  }
}