// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// iOS Safari only applies :active (the press-in on buttons and cards) when a
// touchstart listener exists somewhere up the tree. A passive no-op is enough.
document.addEventListener("touchstart", () => {}, { passive: true })
