# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# Guards Issue #570 — high-write caches must use ID-based keys with `expires_in`,
# not `cache_key_with_version`. The version-based form busts on every cascading
# `touch: true`, which under sustained crack load (HashcatStatus inserts every
# 5–30s × N agents, HashItem cracks at ~1k/sec) collapses cache hit rate to ~0.
#
# Companion guard: `HashcatStatus` must not declare `touch: true` on `:task`,
# because the cascade `HashcatStatus → Task → Attack` was the original cause
# of `CampaignEtaCalculator` cache thrash.
#
# See docs/solutions/best-practices/cache-key-strategy.md for the full policy.
RSpec.describe "cache strategy invariants" do # rubocop:disable RSpec/DescribeClass
  # Files whose Rails.cache.fetch calls must use ID-based keys, never
  # version-based. The check filters comment lines so documentation
  # references (e.g., "# avoid cache_key_with_version") don't trigger
  # false positives.
  volatile_cache_files = %w[
    app/services/campaign_eta_calculator.rb
    app/models/hash_list.rb
  ].freeze

  volatile_cache_files.each do |path|
    it "#{path} does not use cache_key_with_version for high-write caches" do
      offending_lines = Rails.root.join(path).each_line.with_index.filter_map do |line, idx|
        next if line.lstrip.start_with?("#") # skip comment lines

        "#{idx + 1}: #{line.chomp}" if line.include?("cache_key_with_version")
      end

      expect(offending_lines).to be_empty,
        "#{path} reintroduced version-based caching for high-write data:\n" \
        "#{offending_lines.join("\n")}\n" \
        "See Issue #570 — use ID-based keys with expires_in instead. " \
        "Policy: docs/solutions/best-practices/cache-key-strategy.md"
    end
  end

  it "HashcatStatus does not declare touch: true on :task" do
    # Runtime reflection is the source of truth here — string-matching the
    # source file caught a false negative when a schema-annotation comment
    # satisfied the regex.
    touch_option = HashcatStatus.reflect_on_association(:task).options[:touch]
    expect(touch_option).to be_falsey,
      "HashcatStatus declares `touch: true` on :task — see Issue #570. " \
      "Cascading touches from status polls were the primary driver of " \
      "CampaignEtaCalculator cache misses."
  end
end
