/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import {Controller} from "@hotwired/stimulus"
import {visit} from "@hotwired/turbo"

// Connects to data-controller="health-refresh"
// Periodically triggers a Turbo visit to refresh the system health dashboard
// without a full-page reload. Includes cache-busting via timestamp parameter.
export default class extends Controller {
  static values = {
    url: String,
    interval: {type: Number, default: 30}
  }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.timer = setInterval(() => {
      this.refresh()
    }, this.intervalValue * 1000)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  refresh() {
    try {
      const cacheBuster = `_cb=${Date.now()}`
      const separator = this.urlValue.includes("?") ? "&" : "?"
      visit(`${this.urlValue}${separator}${cacheBuster}`, {action: "replace"})
    } catch (error) {
      console.debug("[health-refresh] Refresh failed:", error.message)
    }
  }
}
