import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("✅ PlayersFilterController connected!")
  }

  submit(event) {
    console.log("🚀 players-filter#submit triggered", event)

    // Visual feedback
    event.target.style.backgroundColor = "#e0e0e0"

    // Submit the form after short delay
    setTimeout(() => {
      const form = this.element.querySelector("form")
      if (form) form.submit()
    }, 100)
  }
}
