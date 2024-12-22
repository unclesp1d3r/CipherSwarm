# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The ApplicationRecord class serves as the base class for models in a Rails application.
# It inherits from ActiveRecord::Base and is marked as a primary abstract class.
# This provides a centralized location to define shared behavior and configuration
# for all application models.
#
# Declaring this class as a primary abstract class ensures that it is not used
# directly for creating instances in the database, but instead serves as a superclass
# for other Active Record models. Any shared logic or application-wide model customizations
# can be included in this class.
#
# == Inheritance
# Models in the application (except ApplicationRecord itself) inherit from this class
# to leverage this shared functionality.
#
# == Configuration Options
# - Declares itself as an abstract class using the +primary_abstract_class+ method.
# - Ensures that only one primary abstract class is set for the entire application.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
