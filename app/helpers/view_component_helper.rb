# frozen_string_literal: true

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
