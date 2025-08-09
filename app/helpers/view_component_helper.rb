# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The ViewComponentHelper module provides utility methods to render and manage
# view components in a Rails application. It includes caching mechanisms and
# context-aware rendering features to enhance performance and flexibility.
#
# == Methods:
#
# - component:
#   Renders a specified component by its name. This method supports optional
#   arguments, caching, and block-based rendering. If a context is specified,
#   the component is rendered within that context.
#
# - render_component_in:
#   Renders a component within a specified context. This is a helper method
#   used by the component method for context-based rendering.
#
# - component_class_for:
#   Resolves a component class based on its name or path. This method determines
#   the fully qualified class name for the component, supporting namespacing conventions.
#
# - component_path:
#   Locates the file path for a component by its name. This is used to determine
#   the appropriate directory and namespace for a component.
#
# - namespace:
#   Extracts the namespace of a component based on its file path. This is used
#   to resolve the correct class name for a component.
#
# == Notes:
#
# - The `component` method includes a caching feature using the cache_keys array.
# - The private methods in this module are used internally to resolve component classes
#   and paths, adhering to Rails naming and directory conventions.
# - Components are expected to follow a naming convention of `{name}_component.rb`.
module ViewComponentHelper
  def component(name, context: nil, **args, &block)
    cache_keys = Array(args.delete(:cache))

    cache_if cache_keys.present?, cache_keys do
      return render_component_in(context, name, **args, &block) if context

      return render component_class_for(name).new(args), &block
    end
  end

  def render_component_in(context, name, **args, &)
    component_class_for(name).new(args).render_in(context, &)
  end

  private

  def component_class_for(path)
    name, namespace = path.to_s.split("/").reverse

    file_name = name + "_component"
    component_name = file_name.classify
    namespace ||= namespace(file_name)
    return (namespace.capitalize + "::" + component_name).constantize unless namespace == "components"

    component_name.constantize
  end

  def component_path(file_name)
    Dir.glob(Rails.root.join("app", "components", "**", file_name + ".rb").to_s).first
  end

  def namespace(file_name)
    file_path = component_path(file_name)
    File.dirname(file_path).split("/").last
  end
end
