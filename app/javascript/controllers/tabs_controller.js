/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import {Controller} from "@hotwired/stimulus"

// Connects to data-controller="tabs"
// WCAG 2.1.1 (Keyboard), 2.4.7 (Focus Visible) compliant tab widget
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {active: {type: Number, default: 0}}

  connect() {
    this.#initializeRoles()
    this.setActiveTab(this.activeValue)
  }

  // Ticketed public action name
  switch(event) {
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    if (index !== -1) {
      this.setActiveTab(index)
    }
  }

  // Alias for backwards compatibility
  showTab(event) {
    this.switch(event)
  }

  // Keyboard navigation per WAI-ARIA Tabs Pattern
  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.currentTarget)
    if (currentIndex === -1) return

    let targetIndex = null

    switch (event.key) {
      case "ArrowRight":
        targetIndex = (currentIndex + 1) % tabs.length
        break
      case "ArrowLeft":
        targetIndex = (currentIndex - 1 + tabs.length) % tabs.length
        break
      case "Home":
        targetIndex = 0
        break
      case "End":
        targetIndex = tabs.length - 1
        break
      default:
        return
    }

    event.preventDefault()
    this.setActiveTab(targetIndex)
    tabs[targetIndex].focus()
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
      const isActive = i === index
      tab.classList.toggle("active", isActive)
      tab.setAttribute("aria-selected", String(isActive))
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    this.panelTargets.forEach((panel, i) => {
      const isActive = i === index
      panel.classList.toggle("d-none", !isActive)
      panel.classList.toggle("active", isActive)
      panel.setAttribute("aria-hidden", String(!isActive))
    })
  }

  // Set role="tab" on tabs that don't already have it
  #initializeRoles() {
    this.tabTargets.forEach((tab) => {
      if (!tab.hasAttribute("role")) {
        tab.setAttribute("role", "tab")
      }
    })
  }
}
