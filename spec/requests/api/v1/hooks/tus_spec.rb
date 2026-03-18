# frozen_string_literal: true

require "rails_helper"

# -- describes a hook endpoint, not a class
RSpec.describe "Api::V1::Hooks::Tus" do
  describe "POST /api/v1/hooks/tus" do
    let(:post_finish_payload) do
      {
        "Type" => "post-finish",
        "Event" => {
          "Upload" => {
            "ID" => "abc123def456",
            "Size" => 104_857_600,
            "SizeIsDeferred" => false,
            "Offset" => 104_857_600,
            "MetaData" => {
              "filename" => "wordlist.txt",
              "filetype" => "text/plain"
            },
            "Storage" => {
              "Type" => "filestore",
              "Path" => "/srv/tusd-data/abc123def456"
            }
          }
        }
      }
    end

    context "with a valid post-finish payload" do
      before do
        # Test env uses null_store — swap to memory_store for cache verification
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      end

      it "caches upload metadata and returns ok" do
        post api_v1_hooks_tus_path,
             params: post_finish_payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)

        cached = Rails.cache.read("tus_upload:abc123def456")
        expect(cached).to be_present
        expect(cached[:file_path]).to eq("/srv/tusd-data/abc123def456")
        expect(cached[:file_size]).to eq(104_857_600)
        expect(cached[:filename]).to eq("wordlist.txt")
      end
    end

    context "with a non-post-finish event type" do
      it "returns ok without caching" do
        payload = { "Type" => "pre-create", "Event" => {} }

        post api_v1_hooks_tus_path,
             params: payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(Rails.cache.read("tus_upload:anything")).to be_nil
      end
    end

    context "with invalid JSON" do
      it "returns bad request" do
        post api_v1_hooks_tus_path,
             params: "not json",
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with missing Upload in event" do
      it "returns bad request" do
        payload = { "Type" => "post-finish", "Event" => {} }

        post api_v1_hooks_tus_path,
             params: payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
