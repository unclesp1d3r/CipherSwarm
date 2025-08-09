class Railsboot::StepperComponent < Railsboot::Component
  ALIGNMENTS = ["vertical", "horizontal"].freeze
  DEFAULT_ALIGNMENT = "vertical".freeze

  renders_many :items, Railsboot::Stepper::ItemComponent

  def initialize(alignment: DEFAULT_ALIGNMENT, tag: "ol", **html_attributes)
    @tag = tag
    @alignment = fetch_or_raise(alignment, ALIGNMENTS)
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "stepper",
      {"stepper-#{@alignment}" => @alignment.to_s == "horizontal"},
      html_attributes[:class]
    )
  end
end
