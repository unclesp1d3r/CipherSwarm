class Railsboot::Stepper::ItemComponent < Railsboot::Component
  def initialize(text: "", active: false, **html_attributes)
    @text = text
    @active = active
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "stepper-item",
      { "active" => @active },
      html_attributes.delete(:class)
    )
  end

  def call
    render(Railsboot::BaseComponent.new(tag: "li", **@html_attributes)) { content }
  end
end
