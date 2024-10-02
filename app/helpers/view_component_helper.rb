# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
# The ViewComponentHelper module provides methods to render view components
# with optional caching and context support.
#
# Methods:
# - component(name, context: nil, **args, &block):
#     Renders a component by its name. Supports optional caching and context.
#     - name: The name of the component to render.
#     - context: Optional context in which to render the component.
#     - args: Additional arguments to pass to the component.
#     - block: Optional block to pass to the component.
#
# - render_component_in(context, name, **args, &block):
#     Renders a component within a given context.
#     - context: The context in which to render the component.
#     - name: The name of the component to render.
#     - args: Additional arguments to pass to the component.
#     - block: Optional block to pass to the component.
#
# - component_class_for(path):
#     Determines the class for a given component path.
#     - path: The path of the component.
#     - Returns: The class of the component.
#
# - component_path(file_name):
#     Finds the file path for a given component file name.
#     - file_name: The file name of the component.
#     - Returns: The file path of the component.
#
# - namespace(file_name):
#     Determines the namespace for a given component file name.
#     - file_name: The file name of the component.
#     - Returns: The namespace of the component.
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
