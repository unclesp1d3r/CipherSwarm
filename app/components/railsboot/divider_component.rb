class Railsboot::DividerComponent < Railsboot::Component
  DEFAULT_COLOR = "secondary-subtle".freeze

  SIZES = [1, 2, 3, 4, 5, 6].freeze
  DEFAULT_SIZE = 1

  def initialize(color: DEFAULT_COLOR, size: DEFAULT_SIZE, **html_attributes)
    @color = color
    @size = size - 1
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "w-100",
      "position-relative",
      html_attributes[:class]
    ).presence
  end

  def hr_class
    classes = ["opacity-100", "text-#{@color}"]
    classes << "border border-#{@size} border-#{@color}" if @size > 0
    class_names(*classes)
  end
end
