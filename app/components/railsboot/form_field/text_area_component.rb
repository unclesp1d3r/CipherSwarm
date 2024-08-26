class Railsboot::FormField::TextAreaComponent < Railsboot::FormField::FieldComponent
  def initialize(form:, name:, **html_attributes)
    @form = form
    @name = name
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      "form-control",
      html_attributes[:class]
    )
  end

  def call
    @form.text_area @name, **@html_attributes
  end
end
