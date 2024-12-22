# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for handling requests related to the home page.
#
# This controller is responsible for rendering the home page of the application,
# which serves as the root URL for the application.
#
# Inherits from ApplicationController to manage shared behavior across all controllers,
# such as error handling and permitted parameter configuration.
class HomeController < ApplicationController

  # Displays the homepage of the application.
  #
  # This method serves as the entry point for the application. It is typically associated
  # with the root path of the application, rendering the default view for users who visit the application.
  #
  # The behavior of this method can be extended or overridden based on specific application requirements.
  #
  # @return [void]
  def index; end
end
