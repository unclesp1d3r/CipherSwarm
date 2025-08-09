# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class EnumInput < SimpleForm::Inputs::CollectionSelectInput
  def initialize(builder, attribute_name, column, input_type, options = {}) # rubocop:disable Metrics/ParameterLists
    raise ArgumentError, "EnumInput requires an enum column." unless column.is_a? ActiveRecord::Enum::EnumType

    # Enum's are only required if we do not allow nil values
    inclusion_validator = builder.object.class.validators_on(attribute_name).find { |v| v.kind == :inclusion }
    options[:required] = inclusion_validator && !inclusion_validator&.options&.dig(:allow_nil)

    # If a prompt & include_blank are both present, we'll show 2 options before our enum values
    # priority is given to the prompt, so we'll remove the include_blank option
    #
    # If our enum is required, we remove the include_blank option (can't be nil)
    # This lets SimpleForm include it for new fields, and exclude for preset fields
    #
    # Otherwise we'll show a blank option before our enum values
    if options[:prompt].present? || options[:required]
      options.delete(:include_blank)
    else
      options[:include_blank] = true
    end

    super
  end
def collection
    @collection ||= begin
      raise ArgumentError,
        "Collections are inferred when using the enum input, custom collections are not allowed." if options.key?(:collection)

      object.defined_enums[attribute_name.to_s].keys.map do |key|
        [key.to_s.humanize, key]
      end
    end
end
end
