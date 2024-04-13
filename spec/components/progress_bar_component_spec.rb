# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressBarComponent, type: :component do
  context "with default label" do
    it "renders a progress bar" do
      render_inline(described_class.new(percentage: 50))

      expect(page).to have_css(".progress")
      expect(page).to have_css(".progress-bar")
    end

    it "renders a progress bar with the correct width" do
      render_inline(described_class.new(percentage: 50))

      expect(page).to have_css(".progress-bar[style='width: 50.00%']")
    end

    it "renders a progress bar with the correct aria attributes" do
      render_inline(described_class.new(percentage: 50))

      expect(page).to have_css(".progress-bar[aria-valuenow='50']")
      expect(page).to have_css(".progress-bar[aria-valuemin='0']")
      expect(page).to have_css(".progress-bar[aria-valuemax='100']")
    end

    it "renders a progress bar with the correct aria label" do
      render_inline(described_class.new(percentage: 50))

      expect(page).to have_css(".progress[aria-label='Label']")
    end
  end
end
