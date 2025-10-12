class Railsboot::BlankSlateComponent < Railsboot::Component
  renders_one :icon
  renders_one :heading, Railsboot::HeadingComponent
  renders_one :description
  renders_one :primary_action
  renders_one :secondary_action

  def initialize(tag: "div", **html_attributes)
    @tag = tag
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "text-center",
      html_attributes.delete(:class)
    )
  end
end
