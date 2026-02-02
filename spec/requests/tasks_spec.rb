# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

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
end
