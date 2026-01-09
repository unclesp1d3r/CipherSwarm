# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe AgentStatusCardSkeletonComponent, type: :component do
  describe "rendering" do
    before do
      render_inline(described_class.new)
    end

    it "renders a card with placeholder classes" do
      expect(page).to have_css(".card.placeholder-glow")
    end

    it "renders placeholder elements in the header" do
      expect(page).to have_css(".card-header .placeholder")
    end

    it "renders placeholder elements in the body" do
      expect(page).to have_css(".card-body .placeholder")
    end

    it "renders placeholder buttons in the footer" do
      expect(page).to have_css(".card-footer .placeholder")
    end

    it "includes h-100 class for consistent height" do
      expect(page).to have_css(".card.h-100")
    end
  end
end
