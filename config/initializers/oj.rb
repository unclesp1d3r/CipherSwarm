# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "oj"

# Use compat mode for Rails integration. `optimize_rails` was deprecated in Oj 3.16+.
Oj.default_options = { mode: :compat }
