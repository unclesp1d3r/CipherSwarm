# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe StatusPillComponent, type: :component do
  it "renders a status pill" do
    expect(
      render_inline(described_class.new(status: "completed"))
    ).to have_css(".text-bg-success", text: "Completed")
  end

  it "renders x-circle icon for failed status" do
    render_inline(described_class.new(status: "failed"))
    expect(page).to have_css("i.bi-x-circle")
  end
end
