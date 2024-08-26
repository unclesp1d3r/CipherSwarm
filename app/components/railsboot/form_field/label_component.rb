class Railsboot::FormField::LabelComponent < Railsboot::Component
  def initialize(form:, **html_attributes)
    @form = form
    @html_attributes = html_attributes
    @attribute = @attribute.presence || html_attributes.delete(:for)

    @html_attributes[:class] = class_names(
      "form-label",
      html_attributes[:class]
    )
  end

  def call
    if content.present?
      @form.label @attribute, content, **@html_attributes
    else
      @form.label @attribute, **@html_attributes
    end
  end
end
