// app/javascript/controllers/index.js
import { application } from "./application"
import { definitionsFromContext } from "@hotwired/stimulus-loading"

const context = require.context(".", true, /_controller\.js$/)
application.load(definitionsFromContext(context))

export { PlayersFilterController } from "./players_filter_controller"
export { RoleFieldsController } from "./role_field_controller"
