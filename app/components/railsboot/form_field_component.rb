class Railsboot::FormFieldComponent < Railsboot::Component
  renders_one :label, lambda { |**html_attributes|
    Railsboot::FormField::LabelComponent.new(form: @form, **html_attributes)
  }

  renders_one :input, types: {
    color_field: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::ColorFieldComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :color_field
    },
    date_field: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::DateFieldComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :date_field
    },
    email_field: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::EmailFieldComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :email_field
    },
    password_field: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::PasswordFieldComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :password_field
    },
    phone_field: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::PhoneFieldComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :phone_field
    },
    select: {
      renders: lambda { |name:, choices: nil, options: {}, **html_attributes|
        Railsboot::FormField::SelectComponent.new(form: @form, name: name, choices: choices, options: options, **html_attributes)
      },
      as: :select
    },
    text_area: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::TextAreaComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :text_area
    },
    text_field: {
      renders: lambda { |name:, **html_attributes|
        Railsboot::FormField::TextFieldComponent.new(form: @form, name: name, **html_attributes)
      },
      as: :text_field
    }
  }

  renders_one :validation, Railsboot::FormField::ValidationComponent
  renders_one :caption, Railsboot::FormField::CaptionComponent

  def initialize(form:, floating: false, **html_attributes)
    @form = form
    @floating = floating
    @html_attributes = html_attributes

    @html_attributes[:class] = class_names(
      ("form-floating" if @floating),
      html_attributes.delete(:class)
    )
  end

  def render?
    @form.present?
  end
end
