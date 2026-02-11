# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Renders shimmer placeholder skeletons matching real component layouts.
#
# Supports multiple layout types for consistent loading states across the application.
#
# == Options
# - type: (Symbol, required) The skeleton layout type (:agent_list, :campaign_list, :health_dashboard).
# - count: (Integer, optional, default: 5) Number of placeholder items to render.
class SkeletonLoaderComponent < ApplicationViewComponent
  option :type, required: true
  option :count, default: proc { 5 }
end
