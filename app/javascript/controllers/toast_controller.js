/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import {Controller} from "@hotwired/stimulus"
import {Toast} from "bootstrap"

// Connects to data-controller="toast"
// Auto-shows and auto-hides Bootstrap toast notifications.
// Removes the element from the DOM after the toast is hidden.
export default class extends Controller {
  static values = {
    autohide: {type: Boolean, default: true},
    delay: {type: Number, default: 5000}
  }

  connect() {
    this.toast = new Toast(this.element, {
      autohide: this.autohideValue,
      delay: this.delayValue
    })
    this.toast.show()

    this.element.addEventListener("hidden.bs.toast", () => {
      this.element.remove()
    })
  }

  disconnect() {
    if (this.toast) {
      this.toast.dispose()
    }
  }
}
