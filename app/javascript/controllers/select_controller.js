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
    if (this.select) return

    this.select = new TomSelect(this.element, {
      allowEmptyOption: this.allowEmptyValue,
      plugins: ['dropdown_input'],
      maxOptions: this.maxOptionsValue
    })
  }

  disconnect() {
    if (this.select) {
      this.select.destroy()
      this.select = null
    }
  }
}
