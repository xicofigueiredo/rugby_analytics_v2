import { Application } from "@hotwired/stimulus"
import PlayersFilterController from "./players_filter_controller"
import RoleFieldsController from "./role_fields_controller"
import UsersFilterController from "./users_filter_controller"
// import ChartsController from "./charts_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

Stimulus.register("players-filter", PlayersFilterController)
Stimulus.register("role-fields", RoleFieldsController)
Stimulus.register("users-filter", UsersFilterController)
// Stimulus.register("charts", ChartsController)

export { application }
