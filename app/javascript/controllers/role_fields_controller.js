import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["playerFields"]

  connect() {
    // Check initial value when the controller connects
    const roleSelect = this.element.querySelector('select[name="user[role]"]')
    if (roleSelect) {
      this.toggleFields(roleSelect.value)
    }
  }

  toggle(event) {
    this.toggleFields(event.target.value)
  }

  toggleFields(value) {
    if (value === "player") {
      this.playerFieldsTarget.style.display = "block"
    } else {
      this.playerFieldsTarget.style.display = "none"
    }
  }
}
