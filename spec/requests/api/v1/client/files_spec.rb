# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Client::Files" do
  let(:agent) { create(:agent) }
  let(:word_list) { create(:word_list) }
  let(:campaign) { create(:campaign) }
  let(:attack) { create(:dictionary_attack, campaign: campaign, word_list: word_list) }
  let!(:task) { create(:task, attack: attack, agent: agent) } # rubocop:disable RSpec/LetSetup -- task must exist for agent authorization

  let(:temp_dir) { Rails.root.join("tmp/test_attack_resources") }
  let(:test_file_path) { File.join(temp_dir, "test-wordlist.txt") }

  before do
    FileUtils.mkdir_p(temp_dir)
    File.write(test_file_path, "password123\nadmin\n")
    word_list.update_columns(file_path: test_file_path, file_name: "test-wordlist.txt") # rubocop:disable Rails/SkipsModelValidations
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "GET /api/v1/client/files/:type/:id" do
    context "with valid agent token and authorized resource" do
      it "returns the file" do
        get api_v1_client_file_download_path(type: "word_list", id: word_list.id),
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "when resource has no file_path" do
      before { word_list.update_columns(file_path: nil) } # rubocop:disable Rails/SkipsModelValidations

      it "returns not found" do
        get api_v1_client_file_download_path(type: "word_list", id: word_list.id),
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with invalid resource type" do
      it "returns not found" do
        get api_v1_client_file_download_path(type: "user", id: 1),
            headers: { "Authorization" => "Bearer #{agent.token}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        get api_v1_client_file_download_path(type: "word_list", id: word_list.id)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
