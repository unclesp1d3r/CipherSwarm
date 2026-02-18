# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Records the application boot time for uptime calculation in the system health dashboard.
Rails.application.config.booted_at = Time.current
