# frozen_string_literal: true

require "rails_helper"

RSpec.describe "agents/_cards" do
  let(:user) { create(:user) }
  let(:agent) { create(:agent, user: user, state: :active, custom_label: "Cache Test Agent") }

  before do
    ability = Ability.new(user)
    assign(:current_user, user)
    allow(view).to receive_messages(current_user: user, current_ability: ability)
  end

  describe "cache-key behavior" do
    it "changes cache_key_with_version when updated_at changes" do
      original_cache_key = agent.cache_key_with_version

      agent.update_column(:updated_at, 1.minute.from_now) # rubocop:disable Rails/SkipsModelValidations
      agent.reload

      expect(agent.cache_key_with_version).not_to eq(original_cache_key),
        "Expected cache_key_with_version to change when updated_at changes, " \
        "but got the same key: #{original_cache_key}"
    end

    it "changes cache_key_with_version when agent state transitions" do
      original_key = agent.cache_key_with_version

      agent.deactivate!
      agent.reload

      expect(agent.cache_key_with_version).not_to eq(original_key),
        "cache_key_with_version must change on state transition to prevent stale rendering"
    end
  end

  describe "rendering" do
    it "renders agent cards" do
      render partial: "agents/cards", locals: { agents: [agent] }

      expect(rendered).to have_text("Cache Test Agent")
    end
  end
end
