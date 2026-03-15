# frozen_string_literal: true

require "rails_helper"

RSpec.describe "agents/_cards" do
  let(:user) { create(:user) }
  let(:agent) { create(:agent, user: user, state: :active, custom_label: "Cache Test Agent") }

  before do
    # Enable fragment caching for this spec
    controller.perform_caching = true
    allow(controller).to receive(:perform_caching).and_return(true)

    # Set up authorization context
    ability = Ability.new(user)
    assign(:current_user, user)
    allow(view).to receive_messages(current_user: user, current_ability: ability)
  end

  after do
    Rails.cache.clear
  end

  describe "cache-key regression" do
    it "invalidates the fragment cache when agent updated_at changes" do
      # First render — populates the cache
      render partial: "agents/cards", locals: { agents: [agent] }
      first_render = rendered

      expect(first_render).to have_text("Cache Test Agent")

      # Capture the cache key used for the first render
      original_cache_key = agent.cache_key_with_version

      # Simulate a model update that changes updated_at (e.g., state or error count change)
      agent.update_column(:updated_at, 1.minute.from_now) # rubocop:disable Rails/SkipsModelValidations
      agent.reload

      new_cache_key = agent.cache_key_with_version

      # The cache key must differ after updated_at changes
      expect(new_cache_key).not_to eq(original_cache_key),
        "Expected cache_key_with_version to change when updated_at changes, " \
        "but got the same key: #{original_cache_key}. " \
        "This means the card would serve stale content after agent state updates."

      # Second render — must produce fresh output (not served from stale cache)
      render partial: "agents/cards", locals: { agents: [agent] }
      second_render = rendered

      expect(second_render).to have_text("Cache Test Agent")
    end

    it "produces different cache keys for different agent states" do
      original_key = agent.cache_key_with_version

      agent.update_column(:updated_at, 2.minutes.from_now) # rubocop:disable Rails/SkipsModelValidations
      agent.reload

      expect(agent.cache_key_with_version).not_to eq(original_key),
        "cache_key_with_version must incorporate updated_at to prevent stale card rendering"
    end
  end
end
