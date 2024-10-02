/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import Pagy from "pagy-module" // if using sprockets, you can remove above line, but make sure you have the appropriate directive if your manifest.js file.

export default class extends Controller {
  connect() {
    Pagy.init(this.element)
  }
}
