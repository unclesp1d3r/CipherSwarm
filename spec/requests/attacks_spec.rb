# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Attacks", type: :request do
  let(:project) { create(:project) }
  let(:user) { create(:user, projects: [project]) }
  let(:campaign) { create(:campaign, project: project) }
  let(:attack) { create(:dictionary_attack, campaign: campaign) }

  describe "GET /new" do
    it "returns http success" do
      sign_in user
      get new_campaign_attack_path(campaign)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      sign_in user
      get edit_campaign_attack_path(campaign, attack)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      sign_in user
      get campaign_attack_path(campaign, attack)
      expect(response).to have_http_status(:success)
    end
  end
end
