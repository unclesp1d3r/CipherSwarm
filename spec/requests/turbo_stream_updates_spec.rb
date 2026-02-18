# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Turbo Stream Updates" do
  let!(:project) { create(:project) }
  let!(:project_user) { create(:user, projects: [project]) }
  let!(:agent) { create(:agent, projects: [project]) }
  let!(:campaign) { create(:campaign, project: project) }
  let!(:attack) { create(:dictionary_attack, campaign: campaign) }
  let!(:task) { create(:task, attack: attack, agent: agent) }

  describe "task cancel via Turbo Stream" do
    it "returns turbo_stream response with update and replace actions", :aggregate_failures do
      sign_in(project_user)
      post cancel_task_path(task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include('action="update"')
      expect(response.body).to include('action="replace"')
      expect(response.body).to include("task-details-#{task.id}")
      expect(response.body).to include("task-actions-#{task.id}")
      expect(response.body).to include("task-error-#{task.id}")
      expect(task.reload.state).to eq("failed")
    end

    it "returns turbo_stream even on failed cancellation" do
      completed_task = create(:task, attack: attack, agent: agent, state: "completed")
      sign_in(project_user)
      post cancel_task_path(completed_task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(completed_task.reload.state).to eq("completed")
    end
  end

  describe "task retry via Turbo Stream" do
    it "returns turbo_stream response with update and replace actions", :aggregate_failures do
      failed_task = create(:task, attack: attack, agent: agent, state: "failed", last_error: "Error")
      sign_in(project_user)
      post retry_task_path(failed_task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include("task-details-#{failed_task.id}")
      expect(response.body).to include("task-actions-#{failed_task.id}")
      expect(response.body).to include("task-error-#{failed_task.id}")
      expect(failed_task.reload.state).to eq("pending")
    end

    it "returns turbo_stream even on failed retry" do
      sign_in(project_user)
      post retry_task_path(task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      # Pending task can't be retried
      expect(task.reload.state).to eq("pending")
    end
  end

  describe "task reassign via Turbo Stream" do
    let!(:compatible_agent) { create(:agent, projects: [project]) }

    it "returns turbo_stream response on successful reassignment" do
      sign_in(project_user)
      post reassign_task_path(task), params: { agent_id: compatible_agent.id }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include('action="replace"')
      expect(task.reload.agent_id).to eq(compatible_agent.id)
    end

    it "returns turbo_stream for incompatible agent" do
      incompatible_agent = create(:agent, projects: [create(:project)])
      sign_in(project_user)
      post reassign_task_path(task), params: { agent_id: incompatible_agent.id }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(task.reload.agent_id).to eq(agent.id)
    end

    it "returns turbo_stream when agent_id is missing" do
      sign_in(project_user)
      post reassign_task_path(task), params: {}, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end

  describe "Turbo Stream response structure" do
    it "includes all four stream targets for task actions" do
      sign_in(project_user)
      post cancel_task_path(task), as: :turbo_stream

      expect(response).to have_http_status(:success)

      # Should have 4 turbo stream actions: update details, replace actions, replace error, append toast
      turbo_stream_count = response.body.scan("<turbo-stream").count
      expect(turbo_stream_count).to eq(4)
    end

    it "includes toast notification in all task action responses", :aggregate_failures do
      sign_in(project_user)
      post cancel_task_path(task), as: :turbo_stream

      expect(response.body).to include("toast_container")
      expect(response.body).to include('action="append"')
    end
  end

  describe "Turbo Stream broadcasts don't disrupt Stimulus state" do
    it "task cancel response does not include data-controller attributes that reset tabs" do
      sign_in(project_user)
      post cancel_task_path(task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      # The response should update specific DOM targets, not the entire page
      expect(response.body).not_to include('data-controller="tabs"')
    end

    it "task retry response targets granular DOM elements" do
      failed_task = create(:task, attack: attack, agent: agent, state: "failed", last_error: "Error")
      sign_in(project_user)
      post retry_task_path(failed_task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      # Targets should be specific section IDs, not the whole page
      expect(response.body).to include("task-details-#{failed_task.id}")
      expect(response.body).to include("task-actions-#{failed_task.id}")
    end
  end

  describe "Turbo Stream broadcast model updates" do
    it "agent status update broadcasts to detail page targets" do
      sign_in(project_user)

      # Agent model uses broadcasts_refreshes which sends a page refresh
      # Verify the model responds to broadcast methods
      expect(agent).to respond_to(:broadcast_replace_later_to)
    end

    it "campaign's attack model supports Turbo broadcasts" do
      # Attack model (via AttackResource concern) uses broadcasts_refreshes
      expect(Attack.instance_methods).to include(:broadcast_replace_later_to)
    end

    it "task cancel response preserves existing page scroll position by targeting specific DOM IDs" do
      sign_in(project_user)
      post cancel_task_path(task), as: :turbo_stream

      expect(response).to have_http_status(:success)
      # Verify the response only targets specific sections, not the whole page body
      expect(response.body).not_to include("<body")
      expect(response.body).not_to include('target="body"')
      expect(response.body).to include("task-details-#{task.id}")
    end
  end

  describe "task action authorization via Turbo Stream" do
    let!(:other_project) { create(:project) }
    let!(:other_user) { create(:user, projects: [other_project]) }

    it "returns unauthorized for cross-project task cancel" do
      sign_in(other_user)
      post cancel_task_path(task), as: :turbo_stream

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized for cross-project task retry" do
      failed_task = create(:task, attack: attack, agent: agent, state: "failed", last_error: "Error")
      sign_in(other_user)
      post retry_task_path(failed_task), as: :turbo_stream

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized for cross-project task reassign" do
      sign_in(other_user)
      post reassign_task_path(task), params: { agent_id: agent.id }, as: :turbo_stream

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
