require "rails_helper"

RSpec.describe CrackersController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/crackers").to route_to("crackers#index")
    end

    it "routes to #new" do
      expect(get: "/crackers/new").to route_to("crackers#new")
    end

    it "routes to #show" do
      expect(get: "/crackers/1").to route_to("crackers#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/crackers/1/edit").to route_to("crackers#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/crackers").to route_to("crackers#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/crackers/1").to route_to("crackers#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/crackers/1").to route_to("crackers#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/crackers/1").to route_to("crackers#destroy", id: "1")
    end
  end
end
