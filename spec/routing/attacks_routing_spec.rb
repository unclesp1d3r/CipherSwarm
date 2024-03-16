require "rails_helper"

RSpec.describe AttacksController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/attacks").to route_to("attacks#index")
    end

    it "routes to #new" do
      expect(get: "/attacks/new").to route_to("attacks#new")
    end

    it "routes to #show" do
      expect(get: "/attacks/1").to route_to("attacks#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/attacks/1/edit").to route_to("attacks#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/attacks").to route_to("attacks#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/attacks/1").to route_to("attacks#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/attacks/1").to route_to("attacks#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/attacks/1").to route_to("attacks#destroy", id: "1")
    end
  end
end
