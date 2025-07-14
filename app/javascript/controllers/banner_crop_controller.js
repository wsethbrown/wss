import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "container", "position"]

  connect() {
    console.log("Banner crop controller connected")
    this.currentDragHandlers = null
    this.initializeExistingImage()
  }

  disconnect() {
    this.cleanupDragHandlers()
  }

  initializeExistingImage() {
    console.log("Checking for existing image...")
    console.log("Preview container hidden?", this.containerTarget.classList.contains('hidden'))
    console.log("Preview image src:", this.previewTarget.src)
    console.log("Preview image complete?", this.previewTarget.complete)
    
    if (this.previewTarget && this.previewTarget.src && this.previewTarget.src !== '' && !this.containerTarget.classList.contains('hidden')) {
      console.log("Existing image found, setting up dragging")
      if (this.previewTarget.complete) {
        console.log("Image already loaded, setting up dragging immediately")
        this.setupImageDragging()
      } else {
        console.log("Waiting for image to load...")
        this.previewTarget.addEventListener('load', () => {
          console.log("Image loaded, setting up dragging")
          this.setupImageDragging()
        }, { once: true })
      }
    } else {
      console.log("No existing image to initialize")
    }
  }

  fileChanged(event) {
    const file = event.target.files[0]
    if (file && file.type.startsWith('image/')) {
      console.log('New file selected:', file.name)
      const reader = new FileReader()
      reader.onload = (e) => {
        console.log('File loaded, updating preview')
        this.previewTarget.src = e.target.result
        this.containerTarget.classList.remove('hidden')
        
        // Reset position to center for new image
        this.positionTarget.value = '50% 50%'
        this.previewTarget.style.objectPosition = '50% 50%'
        this.previewTarget.style.transform = 'scale(1.1)'
        
        // Wait for the new image to load before setting up dragging
        this.previewTarget.addEventListener('load', () => {
          console.log('New image loaded, setting up dragging')
          this.setupImageDragging()
        }, { once: true })
      }
      reader.readAsDataURL(file)
    } else {
      console.log('No valid file selected')
    }
  }

  setupImageDragging() {
    console.log('Setting up image dragging...')
    
    // Clean up existing handlers
    this.cleanupDragHandlers()
    
    let isDragging = false
    let startX, startY
    
    // Parse initial position from current value or default to center
    const currentPosition = this.positionTarget.value || 'center center'
    let initialX = 50, initialY = 50
    
    if (currentPosition.includes('%')) {
      const parts = currentPosition.split(' ')
      initialX = parseFloat(parts[0])
      initialY = parseFloat(parts[1])
    }
    
    const mousedownHandler = (e) => {
      console.log('Mouse down on image')
      isDragging = true
      startX = e.clientX
      startY = e.clientY
      this.previewTarget.style.cursor = 'grabbing'
      e.preventDefault()
    }
    
    const mousemoveHandler = (e) => {
      if (!isDragging) return
      
      const deltaX = e.clientX - startX
      const deltaY = e.clientY - startY
      
      const container = this.previewTarget.parentElement
      const containerRect = container.getBoundingClientRect()
      
      // Calculate new position as percentage
      const newX = Math.max(0, Math.min(100, initialX - (deltaX / containerRect.width * 100)))
      const newY = Math.max(0, Math.min(100, initialY - (deltaY / containerRect.height * 100)))
      
      this.previewTarget.style.objectPosition = `${newX}% ${newY}%`
      this.positionTarget.value = `${newX}% ${newY}%`
    }
    
    const mouseupHandler = () => {
      if (isDragging) {
        console.log('Mouse up, stopping drag')
        isDragging = false
        this.previewTarget.style.cursor = 'move'
        
        // Update initial position for next drag
        const position = this.positionTarget.value.split(' ')
        initialX = parseFloat(position[0])
        initialY = parseFloat(position[1])
      }
    }
    
    const touchstartHandler = (e) => {
      isDragging = true
      const touch = e.touches[0]
      startX = touch.clientX
      startY = touch.clientY
      e.preventDefault()
    }
    
    const touchmoveHandler = (e) => {
      if (!isDragging) return
      
      const touch = e.touches[0]
      const deltaX = touch.clientX - startX
      const deltaY = touch.clientY - startY
      
      const container = this.previewTarget.parentElement
      const containerRect = container.getBoundingClientRect()
      
      const newX = Math.max(0, Math.min(100, initialX - (deltaX / containerRect.width * 100)))
      const newY = Math.max(0, Math.min(100, initialY - (deltaY / containerRect.height * 100)))
      
      this.previewTarget.style.objectPosition = `${newX}% ${newY}%`
      this.positionTarget.value = `${newX}% ${newY}%`
      
      e.preventDefault()
    }
    
    const touchendHandler = () => {
      if (isDragging) {
        isDragging = false
        
        const position = this.positionTarget.value.split(' ')
        initialX = parseFloat(position[0])
        initialY = parseFloat(position[1])
      }
    }
    
    // Add event listeners
    this.previewTarget.addEventListener('mousedown', mousedownHandler)
    document.addEventListener('mousemove', mousemoveHandler)
    document.addEventListener('mouseup', mouseupHandler)
    this.previewTarget.addEventListener('touchstart', touchstartHandler)
    document.addEventListener('touchmove', touchmoveHandler)
    document.addEventListener('touchend', touchendHandler)
    
    // Set cursor style
    this.previewTarget.style.cursor = 'move'
    
    // Store handlers for cleanup
    this.currentDragHandlers = {
      mousedown: mousedownHandler,
      mousemove: mousemoveHandler,
      mouseup: mouseupHandler,
      touchstart: touchstartHandler,
      touchmove: touchmoveHandler,
      touchend: touchendHandler
    }
    
    console.log('Image dragging setup complete')
  }

  cleanupDragHandlers() {
    if (this.currentDragHandlers) {
      console.log('Cleaning up drag handlers')
      this.previewTarget.removeEventListener('mousedown', this.currentDragHandlers.mousedown)
      document.removeEventListener('mousemove', this.currentDragHandlers.mousemove)
      document.removeEventListener('mouseup', this.currentDragHandlers.mouseup)
      this.previewTarget.removeEventListener('touchstart', this.currentDragHandlers.touchstart)
      document.removeEventListener('touchmove', this.currentDragHandlers.touchmove)
      document.removeEventListener('touchend', this.currentDragHandlers.touchend)
      this.currentDragHandlers = null
    }
  }
}