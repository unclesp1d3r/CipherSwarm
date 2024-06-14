# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Campaigns", type: :request do
  let!(:admin) { create(:user, role: :admin, projects: [create(:project)]) }

  describe "GET /index" do
    context "when user is not logged in" do
      it { expect(get(campaigns_path)).to redirect_to(new_user_session_path) }
    end

    context "when user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get campaigns_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
