/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import {Application} from "@hotwired/stimulus"
import * as ActiveStorage from "@rails/activestorage"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export {application}

ActiveStorage.start()
