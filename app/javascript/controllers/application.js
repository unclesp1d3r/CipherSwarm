import {Application} from "@hotwired/stimulus"
import * as ActiveStorage from "@rails/activestorage"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export {application}

ActiveStorage.start()
