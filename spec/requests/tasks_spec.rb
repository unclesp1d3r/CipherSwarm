# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "csv"

RSpec.describe "Tasks" do
  let!(:project) { create(:project) }
  let!(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }
  let!(:non_project_user) { create(:user) }
  let!(:project_user) { create(:user, projects: [project]) }
  let!(:agent) { create(:agent, projects: [project]) }
  let!(:campaign) { create(:campaign, project: project) }
  let!(:attack) { create(:dictionary_attack, campaign: campaign) }
  let!(:task) { create(:task, attack: attack, agent: agent) }

  describe "GET /show" do
    context "when user is not logged in" do
      it "redirects to login page" do
        expect(get(task_path(task))).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        get task_path(task)
        expect(response).to have_http_status(:unauthorized)
        expect(response).to render_template("errors/not_authorized")
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get task_path(task)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end

    context "when an admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get task_path(task)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:show)
      end
    end

    context "when task does not exist" do
      it "returns http not found" do
        sign_in(project_user)
        get task_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /cancel" do
    context "when user is not logged in" do
      it "redirects to login page" do
        expect(post(cancel_task_path(task))).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        post cancel_task_path(task)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a project user is logged in" do
      context "with a pending task" do
        it "cancels the task and redirects with notice" do
          sign_in(project_user)
          post cancel_task_path(task)
          expect(response).to redirect_to(task_path(task))
          expect(flash[:notice]).to eq("Task was successfully cancelled.")
          expect(task.reload.state).to eq("failed")
        end
      end

      context "with a running task" do
        let!(:running_task) { create(:task, attack: attack, agent: agent, state: "running") }

        it "cancels the task and redirects with notice" do
          sign_in(project_user)
          post cancel_task_path(running_task)
          expect(response).to redirect_to(task_path(running_task))
          expect(flash[:notice]).to eq("Task was successfully cancelled.")
          expect(running_task.reload.state).to eq("failed")
        end
      end

      context "with a completed task" do
        let!(:completed_task) { create(:task, attack: attack, agent: agent, state: "completed") }

        it "fails to cancel and redirects with alert" do
          sign_in(project_user)
          post cancel_task_path(completed_task)
          expect(response).to redirect_to(task_path(completed_task))
          expect(flash[:alert]).to include("could not be cancelled")
          expect(completed_task.reload.state).to eq("completed")
        end
      end

      context "with a failed task" do
        let!(:failed_task) { create(:task, attack: attack, agent: agent, state: "failed") }

        it "fails to cancel and redirects with alert" do
          sign_in(project_user)
          post cancel_task_path(failed_task)
          expect(response).to redirect_to(task_path(failed_task))
          expect(flash[:alert]).to include("could not be cancelled")
          expect(failed_task.reload.state).to eq("failed")
        end
      end

      context "when requesting turbo_stream format" do
        it "returns turbo_stream response on successful cancellation" do
          sign_in(project_user)
          post cancel_task_path(task), as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
          expect(response.body).to include('action="replace"')
          expect(task.reload.state).to eq("failed")
        end

        it "returns turbo_stream response on failed cancellation" do
          completed_task = create(:task, attack: attack, agent: agent, state: "completed")
          sign_in(project_user)
          post cancel_task_path(completed_task), as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
          expect(completed_task.reload.state).to eq("completed")
        end
      end
    end

    context "when an admin user is logged in" do
      it "cancels the task successfully" do
        sign_in(admin)
        post cancel_task_path(task)
        expect(response).to redirect_to(task_path(task))
        expect(flash[:notice]).to eq("Task was successfully cancelled.")
        expect(task.reload.state).to eq("failed")
      end
    end
  end

  describe "POST /retry" do
    context "when user is not logged in" do
      it "redirects to login page" do
        expect(post(retry_task_path(task))).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      let!(:failed_task) { create(:task, attack: attack, agent: agent, state: "failed") }

      it "returns http unauthorized" do
        sign_in(non_project_user)
        post retry_task_path(failed_task)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a project user is logged in" do
      context "with a failed task" do
        let!(:failed_task) { create(:task, attack: attack, agent: agent, state: "failed", last_error: "Some error") }

        it "retries the task and redirects with notice" do
          sign_in(project_user)
          expect { post retry_task_path(failed_task) }.to change { failed_task.reload.retry_count }.by(1)
          expect(response).to redirect_to(task_path(failed_task))
          expect(flash[:notice]).to eq("Task was successfully queued for retry.")
          expect(failed_task.reload.state).to eq("pending")
          expect(failed_task.last_error).to be_nil
        end
      end

      context "with a pending task" do
        it "fails to retry and redirects with alert" do
          sign_in(project_user)
          post retry_task_path(task)
          expect(response).to redirect_to(task_path(task))
          expect(flash[:alert]).to include("could not be retried")
          expect(task.reload.state).to eq("pending")
        end
      end

      context "with a running task" do
        let!(:running_task) { create(:task, attack: attack, agent: agent, state: "running") }

        it "fails to retry and redirects with alert" do
          sign_in(project_user)
          post retry_task_path(running_task)
          expect(response).to redirect_to(task_path(running_task))
          expect(flash[:alert]).to include("could not be retried")
          expect(running_task.reload.state).to eq("running")
        end
      end

      context "with a completed task" do
        let!(:completed_task) { create(:task, attack: attack, agent: agent, state: "completed") }

        it "fails to retry and redirects with alert" do
          sign_in(project_user)
          post retry_task_path(completed_task)
          expect(response).to redirect_to(task_path(completed_task))
          expect(flash[:alert]).to include("could not be retried")
          expect(completed_task.reload.state).to eq("completed")
        end
      end

      context "when requesting turbo_stream format" do
        it "returns turbo_stream response on successful retry" do
          failed_task = create(:task, attack: attack, agent: agent, state: "failed", last_error: "Some error")
          sign_in(project_user)
          post retry_task_path(failed_task), as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
          expect(response.body).to include('action="replace"')
          expect(failed_task.reload.state).to eq("pending")
        end

        it "returns turbo_stream response on failed retry" do
          sign_in(project_user)
          post retry_task_path(task), as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
          expect(task.reload.state).to eq("pending")
        end
      end
    end

    context "when an admin user is logged in" do
      let!(:failed_task) { create(:task, attack: attack, agent: agent, state: "failed") }

      it "retries the task successfully" do
        sign_in(admin)
        post retry_task_path(failed_task)
        expect(response).to redirect_to(task_path(failed_task))
        expect(flash[:notice]).to eq("Task was successfully queued for retry.")
        expect(failed_task.reload.state).to eq("pending")
      end
    end
  end

  describe "GET /logs" do
    context "when user is not logged in" do
      it "redirects to login page" do
        expect(get(logs_task_path(task))).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        get logs_task_path(task)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a project user is logged in" do
      it "returns http success" do
        sign_in(project_user)
        get logs_task_path(task)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:logs)
      end

      context "with hashcat statuses" do
        let!(:oldest_status) { create(:hashcat_status, task: task, time: 2.hours.ago) }
        let!(:middle_status) { create(:hashcat_status, task: task, time: 1.hour.ago) }
        let!(:newest_status) { create(:hashcat_status, task: task, time: 30.minutes.ago) }

        it "displays statuses in the response" do
          sign_in(project_user)
          get logs_task_path(task)
          expect(response).to have_http_status(:success)
          # Verify all statuses are present in the response body
          expect(response.body).to include(oldest_status.time.strftime("%Y-%m-%d %H:%M:%S"))
          expect(response.body).to include(middle_status.time.strftime("%Y-%m-%d %H:%M:%S"))
          expect(response.body).to include(newest_status.time.strftime("%Y-%m-%d %H:%M:%S"))
        end
      end

      context "with pagination" do
        before do
          # Create more than 50 statuses to test pagination
          55.times do |i|
            create(:hashcat_status, task: task, time: (60 - i).minutes.ago)
          end
        end

        it "paginates results showing first page" do
          sign_in(project_user)
          get logs_task_path(task)
          expect(response).to have_http_status(:success)
          # Check that pagination nav is present (more than 1 page)
          expect(response.body).to include('page=2')
        end

        it "supports page parameter" do
          sign_in(project_user)
          get logs_task_path(task), params: { page: 2 }
          expect(response).to have_http_status(:success)
          # Second page should have link back to page 1
          expect(response.body).to include('page=1')
        end
      end

      context "without any statuses" do
        it "returns http success with empty message" do
          sign_in(project_user)
          get logs_task_path(task)
          expect(response).to have_http_status(:success)
          expect(response.body).to include("No status history available")
        end
      end
    end

    context "when an admin user is logged in" do
      it "returns http success" do
        sign_in(admin)
        get logs_task_path(task)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:logs)
      end
    end

    context "when task does not exist" do
      it "returns http not found" do
        sign_in(project_user)
        get logs_task_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /download_results" do
    let!(:hash_list) { campaign.hash_list }

    context "when user is not logged in" do
      it "returns unauthorized for CSV request" do
        get download_results_task_path(task, format: :csv)
        expect(response).to have_http_status(:unauthorized)
      end

      it "redirects to login page for HTML request" do
        expect(get(download_results_task_path(task))).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        get download_results_task_path(task, format: :csv)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a project user is logged in" do
      before { sign_in(project_user) }

      context "with cracked hashes" do
        before do
          create(:hash_item, :cracked_recently,
            hash_list: hash_list,
            hash_value: "abc123",
            plain_text: "password1",
            cracked_time: Time.zone.parse("2025-01-15 10:30:00"))
          create(:hash_item, :cracked_recently,
            hash_list: hash_list,
            hash_value: "def456",
            plain_text: "password2",
            cracked_time: Time.zone.parse("2025-01-16 14:45:00"))
        end

        let(:uncracked_hash) { create(:hash_item, hash_list: hash_list) }

        it "returns a CSV file with cracked hashes" do
          get download_results_task_path(task, format: :csv)
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include("text/csv")
        end

        it "includes proper CSV headers" do
          get download_results_task_path(task, format: :csv)
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to eq(["Hash", "Plaintext", "Cracked At"])
        end

        it "includes only cracked hashes in the CSV" do
          # Create uncracked hash to verify it's excluded
          uncracked_hash
          get download_results_task_path(task, format: :csv)
          csv = CSV.parse(response.body, headers: true)
          expect(csv.count).to eq(2)
          hash_values = csv.pluck("Hash")
          expect(hash_values).to include("abc123", "def456")
          expect(hash_values).not_to include(uncracked_hash.hash_value)
        end

        it "includes plaintext and cracked_time in the CSV" do
          get download_results_task_path(task, format: :csv)
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r["Hash"] == "abc123" }
          expect(row["Plaintext"]).to eq("password1")
          expect(row["Cracked At"]).to be_present
        end

        it "sets the correct filename in Content-Disposition header" do
          get download_results_task_path(task, format: :csv)
          # Verify filename follows expected pattern: task_{id}_results_{timestamp}.csv
          expect(response.headers["Content-Disposition"]).to match(/task_#{task.id}_results_\d{8}_\d{6}\.csv/)
        end
      end

      context "with no cracked hashes" do
        it "returns a CSV with headers only" do
          get download_results_task_path(task, format: :csv)
          expect(response).to have_http_status(:success)
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to eq(["Hash", "Plaintext", "Cracked At"])
          expect(csv.count).to eq(0)
        end
      end

      context "when requesting HTML format" do
        it "redirects with alert" do
          get download_results_task_path(task, format: :html)
          expect(response).to redirect_to(task_path(task))
          expect(flash[:alert]).to eq("CSV format required")
        end
      end
    end

    context "when an admin user is logged in" do
      before { sign_in(admin) }

      it "returns a CSV file successfully" do
        get download_results_task_path(task, format: :csv)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("text/csv")
      end
    end
  end

  describe "POST /reassign" do
    let!(:compatible_agent) { create(:agent, projects: [project]) }
    let!(:incompatible_agent) { create(:agent, projects: [create(:project)]) }
    let!(:unrestricted_agent) { create(:agent, projects: []) }

    context "when user is not logged in" do
      it "redirects to login page" do
        expect(post(reassign_task_path(task), params: { agent_id: compatible_agent.id })).to redirect_to(new_user_session_path)
      end
    end

    context "when a non-project user is logged in" do
      it "returns http unauthorized" do
        sign_in(non_project_user)
        post reassign_task_path(task), params: { agent_id: compatible_agent.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a project user is logged in" do
      context "with a pending task" do
        it "reassigns the task to a compatible agent" do
          sign_in(project_user)
          post reassign_task_path(task), params: { agent_id: compatible_agent.id }
          expect(response).to redirect_to(task_path(task))
          expect(flash[:notice]).to eq("Task was successfully reassigned.")
          expect(task.reload.agent_id).to eq(compatible_agent.id)
        end

        it "reassigns the task to an unrestricted agent" do
          sign_in(project_user)
          post reassign_task_path(task), params: { agent_id: unrestricted_agent.id }
          expect(response).to redirect_to(task_path(task))
          expect(flash[:notice]).to eq("Task was successfully reassigned.")
          expect(task.reload.agent_id).to eq(unrestricted_agent.id)
        end

        it "fails to reassign to an incompatible agent" do
          sign_in(project_user)
          post reassign_task_path(task), params: { agent_id: incompatible_agent.id }
          expect(response).to redirect_to(task_path(task))
          expect(flash[:alert]).to include("not compatible")
          expect(task.reload.agent_id).to eq(agent.id)
        end
      end

      context "with a failed task" do
        let!(:failed_task) { create(:task, attack: attack, agent: agent, state: "failed") }

        it "reassigns the task to a compatible agent" do
          sign_in(project_user)
          post reassign_task_path(failed_task), params: { agent_id: compatible_agent.id }
          expect(response).to redirect_to(task_path(failed_task))
          expect(flash[:notice]).to eq("Task was successfully reassigned.")
          expect(failed_task.reload.agent_id).to eq(compatible_agent.id)
        end
      end

      context "with a running task" do
        let!(:running_task) { create(:task, attack: attack, agent: agent, state: "running") }

        it "reassigns the task and abandons it" do
          sign_in(project_user)
          post reassign_task_path(running_task), params: { agent_id: compatible_agent.id }
          expect(response).to redirect_to(task_path(running_task))
          expect(flash[:notice]).to eq("Task was successfully reassigned.")
          running_task.reload
          expect(running_task.agent_id).to eq(compatible_agent.id)
          expect(running_task.state).to eq("pending")
        end
      end

      context "with a completed task" do
        let!(:completed_task) { create(:task, attack: attack, agent: agent, state: "completed") }

        it "fails to reassign completed task" do
          sign_in(project_user)
          post reassign_task_path(completed_task), params: { agent_id: compatible_agent.id }
          expect(response).to redirect_to(task_path(completed_task))
          expect(flash[:alert]).to include("cannot be reassigned")
          expect(completed_task.reload.agent_id).to eq(agent.id)
        end
      end

      context "with an exhausted task" do
        let!(:exhausted_task) { create(:task, attack: attack, agent: agent, state: "exhausted") }

        it "fails to reassign exhausted task" do
          sign_in(project_user)
          post reassign_task_path(exhausted_task), params: { agent_id: compatible_agent.id }
          expect(response).to redirect_to(task_path(exhausted_task))
          expect(flash[:alert]).to include("cannot be reassigned")
          expect(exhausted_task.reload.agent_id).to eq(agent.id)
        end
      end

      context "when agent_id is missing" do
        it "fails with appropriate error" do
          sign_in(project_user)
          post reassign_task_path(task), params: {}
          expect(response).to redirect_to(task_path(task))
          expect(flash[:alert]).to include("select an agent")
        end
      end

      context "when agent does not exist" do
        it "returns not found" do
          sign_in(project_user)
          post reassign_task_path(task), params: { agent_id: 999_999 }
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when requesting turbo_stream format" do
        it "returns turbo_stream response on successful reassignment" do
          sign_in(project_user)
          post reassign_task_path(task), params: { agent_id: compatible_agent.id }, as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
          expect(response.body).to include('action="replace"')
          expect(task.reload.agent_id).to eq(compatible_agent.id)
        end

        it "returns turbo_stream response for incompatible agent" do
          sign_in(project_user)
          post reassign_task_path(task), params: { agent_id: incompatible_agent.id }, as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
          expect(task.reload.agent_id).to eq(agent.id)
        end

        it "returns turbo_stream response when agent_id is missing" do
          sign_in(project_user)
          post reassign_task_path(task), params: {}, as: :turbo_stream
          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("turbo-stream")
        end
      end
    end

    context "when an admin user is logged in" do
      it "reassigns the task successfully" do
        sign_in(admin)
        post reassign_task_path(task), params: { agent_id: compatible_agent.id }
        expect(response).to redirect_to(task_path(task))
        expect(flash[:notice]).to eq("Task was successfully reassigned.")
        expect(task.reload.agent_id).to eq(compatible_agent.id)
      end
    end
  end
end
