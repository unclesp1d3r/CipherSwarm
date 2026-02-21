# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Pagy 43.x initializer
# See https://ddnexus.github.io/pagy/docs/guides/quick-start/

# Global defaults
# Pagy.options[:limit] = 20          # default items per page
# Pagy.options[:size]  = [1, 4, 4, 1] # nav bar structure

# Rails JavaScript asset path (for series_nav_js / input_nav_js helpers)
if defined?(Pagy::ROOT)
  Rails.application.config.assets.paths << Pagy::ROOT.join("javascripts")
end
