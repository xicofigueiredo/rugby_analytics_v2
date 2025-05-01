// app/javascript/controllers/application.js
import { Application } from "@hotwired/stimulus"

console.log("✅ Initializing Stimulus...")

const application = Application.start()
application.debug = true
window.Stimulus = application

console.log("✅ Stimulus initialized!")

export { application }
