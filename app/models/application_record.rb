# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Base class for all models in the application.
#
# @configuration
# - primary_abstract_class: ensures single inheritance point
# - provides shared behavior and configuration for all models
#
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
