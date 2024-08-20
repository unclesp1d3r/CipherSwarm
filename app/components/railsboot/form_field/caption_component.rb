class Railsboot::FormField::CaptionComponent < Railsboot::Component
  def initialize(tag: "div", **html_attributes)
    @tag = tag
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "form-text",
      html_attributes[:class]
    )
  end

  def call
    render(Railsboot::BaseComponent.new(tag: @tag, **@html_attributes)) { content }
  end
end
