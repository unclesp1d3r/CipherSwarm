# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Authorization" do
  let!(:project_a) { create(:project) }
  let!(:project_b) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:user_a) { create(:user, projects: [project_a]) }
  let!(:user_b) { create(:user, projects: [project_b]) }
  let!(:agent_a) { create(:agent, user: user_a, projects: [project_a]) }
  let!(:agent_b) { create(:agent, user: user_b, projects: [project_b]) }
  let!(:campaign_a) { create(:campaign, project: project_a) }
  let!(:campaign_b) { create(:campaign, project: project_b) }
  let!(:attack_a) { create(:dictionary_attack, campaign: campaign_a) }
  let!(:attack_b) { create(:dictionary_attack, campaign: campaign_b) }
  let!(:task_a) { create(:task, attack: attack_a, agent: agent_a) }
  let!(:task_b) { create(:task, attack: attack_b, agent: agent_b) }

  describe "task access control" do
    context "when user accesses task in their project" do
      it "returns success" do
        sign_in(user_a)
        get task_path(task_a)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user accesses task outside their project" do
      it "returns unauthorized" do
        sign_in(user_a)
        get task_path(task_b)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when admin accesses any task" do
      it "returns success" do
        sign_in(admin)
        get task_path(task_b)
        expect(response).to have_http_status(:success)
      end
    end

    context "when unauthenticated user accesses task" do
      it "redirects to login" do
        get task_path(task_a)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "campaign access control" do
    context "when user accesses campaign in their project" do
      it "returns success" do
        sign_in(user_a)
        get campaign_path(campaign_a)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user accesses campaign outside their project" do
      it "returns unauthorized" do
        sign_in(user_a)
        get campaign_path(campaign_b)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when admin accesses any campaign" do
      it "returns success" do
        sign_in(admin)
        get campaign_path(campaign_b)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "agent access control" do
    context "when user accesses their own agent" do
      it "returns success" do
        sign_in(user_a)
        get agent_path(agent_a)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user accesses agent in different project" do
      it "returns unauthorized" do
        sign_in(user_a)
        get agent_path(agent_b)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when admin accesses any agent" do
      it "returns success" do
        sign_in(admin)
        get agent_path(agent_b)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "task action authorization" do
    context "when performing cancel action" do
      it "allows project user to cancel task in their project" do
        sign_in(user_a)
        post cancel_task_path(task_a)
        expect(response).to redirect_to(task_path(task_a))
        expect(task_a.reload.state).to eq("failed")
      end

      it "denies non-project user from cancelling task" do
        sign_in(user_b)
        post cancel_task_path(task_a)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when performing retry action" do
      let!(:failed_task_a) { create(:task, attack: attack_a, agent: agent_a, state: "failed", last_error: "Error") }

      it "allows project user to retry task in their project" do
        sign_in(user_a)
        post retry_task_path(failed_task_a)
        expect(response).to redirect_to(task_path(failed_task_a))
        expect(failed_task_a.reload.state).to eq("pending")
      end

      it "denies non-project user from retrying task" do
        sign_in(user_b)
        post retry_task_path(failed_task_a)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when performing reassign action" do
      let!(:compatible_agent) { create(:agent, projects: [project_a]) }

      it "allows project user to reassign task in their project" do
        sign_in(user_a)
        post reassign_task_path(task_a), params: { agent_id: compatible_agent.id }
        expect(response).to redirect_to(task_path(task_a))
        expect(task_a.reload.agent_id).to eq(compatible_agent.id)
      end

      it "denies non-project user from reassigning task" do
        sign_in(user_b)
        post reassign_task_path(task_a), params: { agent_id: compatible_agent.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when performing download_results action" do
      before { task_a.update_columns(state: "completed") } # rubocop:disable Rails/SkipsModelValidations

      it "allows project user to download results" do
        sign_in(user_a)
        get download_results_task_path(task_a, format: :csv)
        expect(response).to have_http_status(:success)
      end

      it "denies non-project user from downloading results" do
        sign_in(user_b)
        get download_results_task_path(task_a, format: :csv)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "hash list access control" do
    let!(:hash_list_a) { create(:hash_list, project: project_a) }
    let!(:hash_list_b) { create(:hash_list, project: project_b) }

    context "when user accesses hash list in their project" do
      it "returns success" do
        sign_in(user_a)
        get hash_list_path(hash_list_a)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user accesses hash list outside their project" do
      it "returns unauthorized" do
        sign_in(user_a)
        get hash_list_path(hash_list_b)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin accesses any hash list" do
      it "returns success" do
        sign_in(admin)
        get hash_list_path(hash_list_b)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "system health access control" do
    before do
      Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
      stub_health_checks
    end

    context "when authenticated user accesses system health" do
      it "returns success" do
        sign_in(user_a)
        get system_health_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when unauthenticated user accesses system health" do
      it "redirects to login" do
        get system_health_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "cross-resource authorization consistency" do
    context "when user tries to access multiple resources in wrong project" do
      it "denies access to all cross-project resources", :aggregate_failures do
        sign_in(user_a)

        get task_path(task_b)
        expect(response).to have_http_status(:unauthorized)

        get campaign_path(campaign_b)
        expect(response).to have_http_status(:unauthorized)

        get agent_path(agent_b)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when admin accesses all resources" do
      it "grants access to all resources", :aggregate_failures do
        sign_in(admin)

        get task_path(task_b)
        expect(response).to have_http_status(:success)

        get campaign_path(campaign_b)
        expect(response).to have_http_status(:success)

        get agent_path(agent_b)
        expect(response).to have_http_status(:success)
      end
    end
  end

  private

  def stub_health_checks
    allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
    allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
    allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
    stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
  end
end
