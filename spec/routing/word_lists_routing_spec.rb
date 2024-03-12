require "rails_helper"

RSpec.describe WordListsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/word_lists").to route_to("word_lists#index")
    end

    it "routes to #new" do
      expect(get: "/word_lists/new").to route_to("word_lists#new")
    end

    it "routes to #show" do
      expect(get: "/word_lists/1").to route_to("word_lists#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/word_lists/1/edit").to route_to("word_lists#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/word_lists").to route_to("word_lists#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/word_lists/1").to route_to("word_lists#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/word_lists/1").to route_to("word_lists#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/word_lists/1").to route_to("word_lists#destroy", id: "1")
    end
  end
end
