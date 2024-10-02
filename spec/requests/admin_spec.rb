# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Admins", type: :request do
  let!(:admin) {
    u = create(:user)
    u.add_role(:admin)
    u
  }
  let!(:regular_user) { create(:user) }

  describe "GET /index" do
    it "returns http success" do
      sign_in admin
      get admin_root_path
      expect(response).to have_http_status(:success)
    end

    it "returns http failure" do
      sign_in regular_user
      get admin_root_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /unlock_user" do
    let!(:locked_user) { create(:user, locked_at: Time.zone.now) }

    context "when the user is an admin" do
      it "returns http success" do
        sign_in admin
        post unlock_user_path(locked_user)
        expect(response).to redirect_to(admin_index_path)
      end

      it "unlocks the locked user" do
        sign_in admin
        post unlock_user_path(locked_user)
        locked_user.reload
        expect(locked_user.locked_at).to be_nil
      end
    end

    context "when the user is not an admin" do
      it "returns http failure" do
        sign_in regular_user
        post unlock_user_path(locked_user)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /lock_user" do
    let!(:unlocked_user) { create(:user, locked_at: nil) }

    context "when the user is an admin" do
      it "returns http success" do
        sign_in admin
        post lock_user_path(unlocked_user)
        expect(response).to redirect_to(admin_index_path)
      end

      it "locks the unlocked user" do
        sign_in admin
        post lock_user_path(unlocked_user)
        unlocked_user.reload
        expect(unlocked_user.locked_at).not_to be_nil
      end
    end

    context "when the user is not an admin" do
      it "returns http failure" do
        sign_in regular_user
        post lock_user_path(unlocked_user)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /create_user" do
    let!(:user) do
      {
        name: Faker::Name.name,
        email: Faker::Internet.email,
        password: "password",
        password_confirmation: "password"
      }
    end

    context "when the user is an admin" do
      it "returns http success" do
        sign_in admin
        post create_user_path, params: { user: }
        expect(response).to redirect_to(admin_index_path)
      end
    end

    context "when the user is not an admin" do
      it "returns http failure" do
        sign_in regular_user
        post create_user_path, params: { user: }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /new_user" do
    context "when the user is an admin" do
      it "returns http success" do
        sign_in admin
        get "/admin/new_user"
        expect(response).to have_http_status(:success)
      end
    end

    context "when the user is not an admin" do
      it "returns http failure" do
        sign_in regular_user
        get "/admin/new_user"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
