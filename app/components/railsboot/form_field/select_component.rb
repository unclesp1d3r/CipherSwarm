class Railsboot::FormField::SelectComponent < Railsboot::FormField::FieldComponent
  def initialize(form:, name:, size: DEFAULT_SIZE, choices: nil, options: {}, **html_attributes)
    @form = form
    @name = name
    @size = fetch_or_fallback(size, SIZES, DEFAULT_SIZE)
    @choices = choices
    @options = options
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "form-select",
      {"form-select-#{@size}" => @size.present?},
      html_attributes[:class]
    )
  end

  def call
    @form.select @name, @choices, @options, **@html_attributes
  end
end
