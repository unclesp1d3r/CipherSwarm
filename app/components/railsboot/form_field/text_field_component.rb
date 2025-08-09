class Railsboot::FormField::TextFieldComponent < Railsboot::FormField::FieldComponent
  def initialize(form:, name:, size: DEFAULT_SIZE, **html_attributes)
    @form = form
    @name = name
    @size = fetch_or_fallback(size, SIZES, DEFAULT_SIZE)
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "form-control",
      {"form-control-#{@size}" => @size.present?},
      html_attributes[:class]
    )
  end

  def call
    @form.text_field @name, **@html_attributes
  end
end
