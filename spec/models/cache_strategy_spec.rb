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
  volatile_cache_files = %w[
    app/services/campaign_eta_calculator.rb
    app/models/hash_list.rb
  ].freeze

  volatile_cache_files.each do |path|
    it "#{path} does not use cache_key_with_version for high-write caches" do
      content = Rails.root.join(path).read
      expect(content).not_to include("cache_key_with_version"),
        "#{path} reintroduced version-based caching for high-write data. " \
        "See Issue #570 — use ID-based keys with expires_in instead. " \
        "Policy: docs/solutions/best-practices/cache-key-strategy.md"
    end
  end

  it "HashcatStatus does not declare touch: true on :task" do
    content = Rails.root.join("app/models/hashcat_status.rb").read
    expect(content).to match(/belongs_to :task(?!,\s*touch)/),
      "HashcatStatus must not declare `touch: true` on :task — see Issue #570. " \
      "Cascading touches from status polls were the primary driver of " \
      "CampaignEtaCalculator cache misses."
  end
end
