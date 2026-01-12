/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import {Controller} from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {active: {type: Number, default: 0}}

  connect() {
    this.setActiveTab(this.activeValue)
  }

  showTab(event) {
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    if (index !== -1) {
      this.setActiveTab(index)
    }
  }

  setActiveTab(index) {
    this.activeValue = index
    this.updateTabs(index)
  }

  activeValueChanged() {
    this.updateTabs(this.activeValue)
  }

  updateTabs(index) {
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add("active")
        tab.setAttribute("aria-selected", "true")
      } else {
        tab.classList.remove("active")
        tab.setAttribute("aria-selected", "false")
      }
    })

    this.panelTargets.forEach((panel, i) => {
      if (i === index) {
        panel.classList.remove("d-none")
        panel.setAttribute("aria-hidden", "false")
      } else {
        panel.classList.add("d-none")
        panel.setAttribute("aria-hidden", "true")
      }
    })
  }
}
