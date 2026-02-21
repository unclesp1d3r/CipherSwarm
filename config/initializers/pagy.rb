# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Pagy 43.x initializer
# See https://ddnexus.github.io/pagy/resources/initializer/

# Global defaults
# Pagy.options[:limit] = 20   # default items per page
# Pagy.options[:slots] = 7    # number of page links in nav bar

# Rails JavaScript asset path (for series_nav_js / input_nav_js helpers)
Rails.application.config.assets.paths << Pagy::ROOT.join("javascripts")
