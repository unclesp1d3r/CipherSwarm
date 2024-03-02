require "rails_helper"

RSpec.describe AdminController, type: :controller do
  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "assigns all users" do
      user1 = create(:user)
      user2 = create(:user)
      get :index
      expect(assigns(:users)).to eq([ user1, user2 ])
    end

    it "assigns all projects" do
      project1 = create(:project)
      project2 = create(:project)
      get :index
      expect(assigns(:projects)).to eq([ project1, project2 ])
    end
  end
end
