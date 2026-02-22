/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Connects to data-controller="select"
export default class extends Controller {
  connect() {
    if (this.select) return

    this.select = new TomSelect(this.element, {
      allowEmptyOption: false,
      plugins: ['dropdown_input'],
      maxOptions: null
    })
  }

  disconnect() {
    if (this.select) {
      this.select.destroy()
      this.select = null
    }
  }
}
