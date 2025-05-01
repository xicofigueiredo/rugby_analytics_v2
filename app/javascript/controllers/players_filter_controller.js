import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("✅ PlayersFilterController connected!")
  }

  submit(event) {
    console.log("🚀 players-filter#submit triggered", event)

    // Visual feedback
    event.target.style.backgroundColor = "#e0e0e0"

    // Submit form with Turbo
    this.requestSubmit(this.element)

    // Reset visual feedback after a short delay
    setTimeout(() => {
      event.target.style.backgroundColor = ""
    }, 200)
  }

  // Helper method to safely submit the form
  requestSubmit(form) {
    if (form.requestSubmit) {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }
}
