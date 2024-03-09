require "rails_helper"

RSpec.describe CrackerBinariesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/cracker_binaries").to route_to("cracker_binaries#index")
    end

    it "routes to #new" do
      expect(get: "/cracker_binaries/new").to route_to("cracker_binaries#new")
    end

    it "routes to #show" do
      expect(get: "/cracker_binaries/1").to route_to("cracker_binaries#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/cracker_binaries/1/edit").to route_to("cracker_binaries#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/cracker_binaries").to route_to("cracker_binaries#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/cracker_binaries/1").to route_to("cracker_binaries#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/cracker_binaries/1").to route_to("cracker_binaries#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/cracker_binaries/1").to route_to("cracker_binaries#destroy", id: "1")
    end
  end
end
