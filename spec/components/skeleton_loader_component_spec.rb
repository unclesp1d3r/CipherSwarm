# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SkeletonLoaderComponent, type: :component do
  describe "agent_list type" do
    it "renders placeholder cards" do
      render_inline(described_class.new(type: :agent_list, count: 3))
      expect(page).to have_css(".placeholder-glow")
      expect(page).to have_css(".card.placeholder-glow", count: 3)
    end

    it "renders with default count of 5" do
      render_inline(described_class.new(type: :agent_list))
      expect(page).to have_css(".card.placeholder-glow", count: 5)
    end
  end

  describe "campaign_list type" do
    it "renders placeholder list items" do
      render_inline(described_class.new(type: :campaign_list, count: 3))
      expect(page).to have_css(".placeholder-glow")
      expect(page).to have_css(".list-group-item", count: 3)
    end

    it "renders progress bar placeholders" do
      render_inline(described_class.new(type: :campaign_list, count: 2))
      expect(page).to have_css(".progress", count: 2)
    end
  end

  describe "health_dashboard type" do
    it "renders placeholder health cards" do
      render_inline(described_class.new(type: :health_dashboard, count: 4))
      expect(page).to have_css(".placeholder-glow")
      expect(page).to have_css(".card.placeholder-glow", count: 4)
    end
  end

  describe "aria attributes" do
    it "includes aria-hidden for accessibility" do
      render_inline(described_class.new(type: :agent_list))
      expect(page).to have_css("[aria-hidden='true']")
    end
  end
end
