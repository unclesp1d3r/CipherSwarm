# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe Downloadable do
  describe "#resource_class" do
    it "resolves controller_path to a model" do
      controller = WordListsController.new
      expect(controller.send(:resource_class)).to eq(WordList)
    end

    it "raises a helpful error when the controller does not map to a model" do
      controller = WordListsController.new
      allow(controller).to receive(:controller_path).and_return("no_such_resources")

      expect { controller.send(:resource_class) }
        .to raise_error(ArgumentError, /Downloadable: cannot resolve model/)
    end
  end
end
