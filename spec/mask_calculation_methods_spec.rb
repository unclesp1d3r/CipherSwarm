# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# spec/mask_calculation_methods_test.rb

require "rails_helper"

RSpec.describe MaskCalculationMethods do
  describe ".calculate_mask_candidates" do
    it "calculates the correct number of candidates for lowercase letters" do
      expect(described_class.calculate_mask_candidates("?l?l")).to eq(BigDecimal(26 * 26))
    end

    it "calculates the correct number of candidates for uppercase letters" do
      expect(described_class.calculate_mask_candidates("?u?u")).to eq(BigDecimal(26 * 26))
    end

    it "calculates the correct number of candidates for digits" do
      expect(described_class.calculate_mask_candidates("?d?d")).to eq(BigDecimal(10 * 10))
    end

    it "calculates the correct number of candidates for special characters" do
      expect(described_class.calculate_mask_candidates("?s?s")).to eq(BigDecimal(33 * 33))
    end

    it "calculates the correct number of candidates for all printable ASCII characters" do
      expect(described_class.calculate_mask_candidates("?a?a")).to eq(BigDecimal(95 * 95))
    end

    it "calculates the correct number of candidates for all bytes" do
      expect(described_class.calculate_mask_candidates("?b?b")).to eq(BigDecimal(256 * 256))
    end

    it "calculates the correct number of candidates for literal characters" do
      expect(described_class.calculate_mask_candidates("yy")).to eq(BigDecimal(1))
    end

    it "calculates the correct number of candidates for a mix of tokens" do
      expect(described_class.calculate_mask_candidates("?a?b?d")).to eq(BigDecimal(95 * 256 * 10))
    end

    it "calculates the correct number of candidates for a mix of literals and tokens" do
      expect(described_class.calculate_mask_candidates("abc?a?d")).to eq(BigDecimal(95 * 10))
    end

    it "calculates 0 candidate for an empty mask" do
      expect(described_class.calculate_mask_candidates("")).to eq(BigDecimal(0))
    end

    it "calculates the correct number of candidates for a mask with unexpected characters" do
      expect(described_class.calculate_mask_candidates("?x?y")).to eq(BigDecimal(1))
    end

    it "calculates mask candidates for ?d?d?d?d?d?d?d?d correctly" do
      expect(described_class.calculate_mask_candidates("?d?d?d?d?d?d?d?d")).to eq(BigDecimal(10 ** 8))
    end

    it "calculates mask candidates for ?d?d?d?d?d?d?d?d?d correctly" do
      expect(described_class.calculate_mask_candidates("?d?d?d?d?d?d?d?d?d")).to eq(BigDecimal(10 ** 9))
    end

    it "calculates mask candidates for ?d?d?d?d?d?d?d?d?d?d correctly" do
      expect(described_class.calculate_mask_candidates("?d?d?d?d?d?d?d?d?d?d")).to eq(BigDecimal(10 ** 10))
    end

    it "calculates mask candidates for ?l?l?d?d?d?d?d?d correctly" do
      expect(described_class.calculate_mask_candidates("?l?l?d?d?d?d?d?d")).to eq(BigDecimal(26 ** 2 * 10 ** 6))
    end

    it "calculates mask candidates for ?u?l?d?d?d?d?d?d correctly" do
      expect(described_class.calculate_mask_candidates("?u?l?d?d?d?d?d?d")).to eq(BigDecimal(26 * 26 * 10 ** 6))
    end

    it "calculates mask candidates for ?l?d?d?d?d?d?d?d correctly" do
      expect(described_class.calculate_mask_candidates("?l?d?d?d?d?d?d?d")).to eq(BigDecimal(26 * 10 ** 7))
    end

    # This just doesn't work yet.
    # it 'calculates candidates for a mask with a custom charset ?d?l,test?1?1?1' do
    #   mask = '?d?l,test?1?1?1'
    #   result = described_class.calculate_mask_candidates(mask)
    #   expected = (10 * 26) * (10 * 26) * (10 * 26)
    #   expect(result).to eq(BigDecimal(expected.to_s))
    # end

    it "calculates candidates for a complex hcmask abcdef,0123,ABC,789,?3?3?3?1?1?1?1?2?2?4?4?4?4" do
      mask = "abcdef,0123,ABC,789,?3?3?3?1?1?1?1?2?2?4?4?4?4"
      result = described_class.calculate_mask_candidates(mask)
      expected = 3 * 3 * 3 * 6 * 6 * 6 * 6 * 4 * 4 * 3 * 3 * 3 * 3 # Based on the specified custom charset values and mask
      expect(result).to eq(BigDecimal(expected.to_s))
    end

    it "calculates candidates for a mask without custom charset company?d?d?d?d?d" do
      mask = "company?d?d?d?d?d"
      result = described_class.calculate_mask_candidates(mask)
      expected = 100000 # 5 digits
      expect(result).to eq(BigDecimal(expected.to_s))
    end

    it "calculates candidates for a mask without custom charset ?l?l?l?l?d?d?d?d?d?d" do
      mask = "?l?l?l?l?d?d?d?d?d?d"
      result = described_class.calculate_mask_candidates(mask)
      expected = 26 * 26 * 26 * 26 * 10 * 10 * 10 * 10 * 10 * 10 # 4 lowercase letters and 6 digits
      expect(result).to eq(BigDecimal(expected.to_s))
    end

    # This just doesn't work yet.
    # it 'calculates candidates for a mixed hcmask ?u?l,?s?d,?1?a?a?a?a?2' do
    #   mask = '?u?l,?s?d,?1?a?a?a?a?2'
    #   result = described_class.calculate_mask_candidates(mask)
    #   expected = 33 * 10 * 33 * 95 * 95 * 95 * 95 * 33 # Based on the specified custom charset and predefined charsets in mask
    #   expect(result).to eq(BigDecimal(expected.to_s))
    # end
  end
end
