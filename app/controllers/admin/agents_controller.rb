# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module Admin
  # This controller manages administrative actions for the `Agent` resource within the `Admin` namespace.
  # It inherits from `Admin::ApplicationController`, leveraging default Administrate controller functionality
  # and providing hooks to customize behavior as needed.
  #
  # You can override default RESTful controller methods like `index`, `show`, `edit`, `update`, `destroy`, etc.,
  # to implement custom functionality specific to the `Agent` resource. The inheritance from
  # `Admin::ApplicationController` includes various utility methods and configurations for resource management.
  #
  # === Customizations and Overrides
  #
  # - `update`:
  #   Override this method to add functionality after an agent is updated, such as triggering an email notification.
  #
  # - `find_resource(param)`:
  #   Customize how a single agent resource is located, which affects the `show`, `edit`, and `update` actions.
  #   By default, it locates resources based on the provided parameter.
  #
  # - `scoped_resource`:
  #   Specify a custom subset of records to display in the `index` action based on the user's role.
  #   For example, differentiate data visibility for super admins vs. regular admins.
  #
  # - `resource_params`:
  #   Apply transformations to incoming data before it is persisted. This method allows you to customize permitted
  #   attributes or modify data, such as converting blank values to `nil`.
  #
  # === Notes:
  # - The controller includes access to `requested_resource`, which represents the current resource being processed.
  # - Customizations should leverage the functionality inherited from `Admin::ApplicationController` and the
  #   Administrate framework to maintain consistency across the admin application.
  #
  # === Additional Resources:
  # For more detailed information and examples around customizing controller actions in Administrate,
  # refer to: https://administrate-demo.herokuapp.com/customizing_controller_actions
  class AgentsController < Admin::ApplicationController
    # Overwrite any of the RESTful controller actions to implement custom behavior
    # For example, you may want to send an email after a foo is updated.
    #
    # def update
    #   super
    #   send_foo_updated_email(requested_resource)
    # end

    # Override this method to specify custom lookup behavior.
    # This will be used to set the resource for the `show`, `edit`, and `update`
    # actions.
    #
    # def find_resource(param)
    #   Foo.find_by!(slug: param)
    # end

    # The result of this lookup will be available as `requested_resource`

    # Override this if you have certain roles that require a subset
    # this will be used to set the records shown on the `index` action.
    #
    # def scoped_resource
    #   if current_user.super_admin?
    #     resource_class
    #   else
    #     resource_class.with_less_stuff
    #   end
    # end

    # Override `resource_params` if you want to transform the submitted
    # data before it's persisted. For example, the following would turn all
    # empty values into nil values. It uses other APIs such as `resource_class`
    # and `dashboard`:
    #
    def resource_params
      params.
        expect(resource_class.model_name.param_key => [dashboard.permitted_attributes(action_name)]).
        transform_values { |value| value == "" ? nil : value }
    end

    # See https://administrate-demo.herokuapp.com/customizing_controller_actions
    # for more information
  end
end
