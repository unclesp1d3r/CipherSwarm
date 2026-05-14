# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "campaigns/_recent_cracks" do
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:project) { create(:project) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:attack) { create(:dictionary_attack, campaign: campaign) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    hash_list.hash_items.delete_all
  end

  describe "when invoked from the broadcast path with uncached: true" do
    it "renders the freshly-committed crack even when the cached recent-cracks values are stale" do
      # Warm the cached recent_cracks and recent_cracks_count keys while empty
      expect(hash_list.recent_cracks_count).to eq(0)
      expect(hash_list.recent_cracks).to be_empty

      # Simulate a new crack committed after the cache was warmed
      create(:hash_item, :cracked_recently, hash_list: hash_list, attack: attack, plain_text: "fresh_pw")

      # The cached values stay stale within their TTL
      expect(hash_list.recent_cracks_count).to eq(0)

      render partial: "campaigns/recent_cracks", locals: { campaign: campaign, uncached: true }

      expect(rendered).to include("fresh_pw")
      expect(rendered).to match(/badge[^>]*>\s*1\s*</)
    end
  end
end
