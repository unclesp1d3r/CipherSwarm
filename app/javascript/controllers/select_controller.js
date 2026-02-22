/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Connects to data-controller="select"
export default class extends Controller {
  static values = {
    allowEmpty: { type: Boolean, default: false },
    maxOptions: { type: Number, default: 100 }
  }

  connect() {
    // Guard against re-initialization from Turbo morphing or reconnection,
    // and prevent retries after a failed initialization attempt.
    if (this.select || this._initFailed) return

    try {
      this.select = new TomSelect(this.element, {
        allowEmptyOption: this.allowEmptyValue,
        plugins: ['dropdown_input'],
        maxOptions: this.maxOptionsValue
      })
    } catch (error) {
      console.error(
        `[SelectController] Failed to initialize TomSelect on #${this.element.id}:`,
        error
      )
      this._initFailed = true
    }
  }

  disconnect() {
    if (this.select) {
      this.select.destroy()
      this.select = null
    }
    this._initFailed = false
  }
}
