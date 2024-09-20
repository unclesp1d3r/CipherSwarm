# frozen_string_literal: true

module MaskCalculationMethods
  def self.calculate_mask_candidates(mask_line)
    require "bigdecimal"

    charset_counts = {
      "?a" => 95, # All printable ASCII characters
      "?d" => 10, # Digits
      "?l" => 26, # Lowercase letters
      "?u" => 26, # Uppercase letters
      "?s" => 33, # Special characters
      "?h" => 16, # Hexadecimal characters (lowercase)
      "?H" => 16, # Hexadecimal characters (uppercase)
      "?b" => 256 # All bytes
    }

    custom_charsets = {}
    mask = mask_line

    if mask_line.include?(",")
      parts = mask_line.split(/(?<!\\),/, 5).map { |part| part.gsub(/\\,/, ",") }
      custom_charsets = {
        "?1" => parts[0],
        "?2" => parts[1],
        "?3" => parts[2],
        "?4" => parts[3]
      }
      mask = parts[4] || ""
    end

    # Return no candidates if the mask is empty or nil
    return BigDecimal(0) if mask.strip.empty?

    variable_candidates = BigDecimal(1) # Counter for variable segments multiplier

    i = 0
    while i < mask.length
      if mask[i] == "?" && i + 1 < mask.length
        composite_char = mask[i..i + 1] # Fetch next two characters
        if custom_charsets[composite_char]
          charset_size = custom_charsets[composite_char].size
          variable_candidates *= BigDecimal(charset_size.to_s)
          i += 1 # skip the next character as part of the pair is used
        elsif charset_counts[composite_char]
          variable_candidates *= BigDecimal(charset_counts[composite_char].to_s)
          i += 1 # skip the next character as part of the pair is used
        else
          # Skip invalid placeholder
          i += 1 # skip the invalid placeholder
        end
      end
      i += 1 # iterate to the next character
    end

    variable_candidates
  end
end
