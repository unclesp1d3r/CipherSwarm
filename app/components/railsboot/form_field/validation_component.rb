class Railsboot::FormField::ValidationComponent < Railsboot::Component
  def initialize(valid: false, tag: "div", **html_attributes)
    @valid = valid
    @tag = tag
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      @valid ? "text-success" : "text-danger",
      "mt-1",
      html_attributes[:class]
    )
  end

  def call
    render(Railsboot::BaseComponent.new(tag: @tag, **@html_attributes)) { content }
  end

  def render?
    content?
  end
end
