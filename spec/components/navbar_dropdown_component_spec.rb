# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe NavbarDropdownComponent, type: :component do
  it "renders some content" do
    expect(
      render_inline(described_class.new(title: "Test Dropdown")) { "Hello, components!" }
        .to_html
    ).to include("Hello, components!")
  end

  it "renders the title" do
    expect(
      render_inline(described_class.new(title: "Test Dropdown")) { "Hello, components!" }
        .to_html
    ).to include("Test Dropdown")
  end

  it "renders the right css" do
    expect(
      render_inline(described_class.new(title: "Test Dropdown")) { "Hello, components!" }
        .to_html
    ).to include("dropdown")
  end
end
