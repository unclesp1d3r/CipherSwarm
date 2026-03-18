# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ActiveStorage::DirectUploadsController" do
  # Direct uploads endpoint does not require agent auth — it uses session-based
  # CSRF protection via ActiveStorage::BaseController.
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "POST /rails/active_storage/direct_uploads" do
    let(:valid_params) do
      {
        blob: {
          filename: "wordlist.txt",
          byte_size: 1024,
          checksum: "dGVzdGNoZWNrc3Vt",
          content_type: "text/plain",
          metadata: {}
        }
      }
    end

    context "with a normal checksum" do
      it "creates a blob with the checksum" do
        post rails_direct_uploads_url, params: valid_params, as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["checksum"]).to eq("dGVzdGNoZWNrc3Vt")
        expect(json["signed_id"]).to be_present
        expect(json["direct_upload"]["url"]).to be_present
        expect(json["direct_upload"]["headers"]).to be_a(Hash)
      end

      it "does not set checksum_skipped metadata" do
        post rails_direct_uploads_url, params: valid_params, as: :json

        blob = ActiveStorage::Blob.find_by(filename: "wordlist.txt")
        expect(blob.metadata).not_to include("checksum_skipped")
      end
    end

    context "with a nil checksum (large file)" do
      let(:nil_checksum_params) do
        {
          blob: {
            filename: "large_wordlist.txt",
            byte_size: 2_147_483_648,
            checksum: nil,
            content_type: "text/plain",
            metadata: {}
          }
        }
      end

      it "creates a blob with nil checksum and checksum_skipped metadata" do
        post rails_direct_uploads_url, params: nil_checksum_params, as: :json

        expect(response).to have_http_status(:ok)
        blob = ActiveStorage::Blob.find_by(filename: "large_wordlist.txt")
        expect(blob.checksum).to be_nil
        expect(blob.metadata["checksum_skipped"]).to be true
      end

      it "returns a valid direct upload URL" do
        post rails_direct_uploads_url, params: nil_checksum_params, as: :json

        json = response.parsed_body
        expect(json["signed_id"]).to be_present
        expect(json["direct_upload"]["url"]).to be_present
      end
    end

    context "with a blank string checksum" do
      let(:blank_checksum_params) do
        {
          blob: {
            filename: "blank_checksum.txt",
            byte_size: 512,
            checksum: "",
            content_type: "text/plain",
            metadata: {}
          }
        }
      end

      it "treats blank checksum the same as nil" do
        post rails_direct_uploads_url, params: blank_checksum_params, as: :json

        expect(response).to have_http_status(:ok)
        blob = ActiveStorage::Blob.find_by(filename: "blank_checksum.txt")
        expect(blob.checksum).to be_nil
        expect(blob.metadata["checksum_skipped"]).to be true
      end
    end
  end
end
