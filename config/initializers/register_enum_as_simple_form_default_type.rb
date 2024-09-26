# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

module RegisterEnumAsSimpleFormDefaultType
  def default_input_type(attribute_name, column, options)
    # If we are explicit about the type, use that
    return options[:as].to_sym if options[:as]

    if column.is_a? ActiveRecord::Enum::EnumType
      # If we are using an enum, use our custom EnumInput
      :enum
    else
      # Otherwise, use the default simple form type lookup
      super
    end
  end
end

# Ensure we prepend this module so it is called before the default lookup
SimpleForm::FormBuilder.prepend(RegisterEnumAsSimpleFormDefaultType)
