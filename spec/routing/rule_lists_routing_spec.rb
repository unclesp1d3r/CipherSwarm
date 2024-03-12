require "rails_helper"

RSpec.describe RuleListsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/rule_lists").to route_to("rule_lists#index")
    end

    it "routes to #new" do
      expect(get: "/rule_lists/new").to route_to("rule_lists#new")
    end

    it "routes to #show" do
      expect(get: "/rule_lists/1").to route_to("rule_lists#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/rule_lists/1/edit").to route_to("rule_lists#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/rule_lists").to route_to("rule_lists#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/rule_lists/1").to route_to("rule_lists#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/rule_lists/1").to route_to("rule_lists#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/rule_lists/1").to route_to("rule_lists#destroy", id: "1")
    end
  end
end
