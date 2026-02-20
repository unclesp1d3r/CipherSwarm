# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Error Handling" do
  let(:admin) {
    user = create(:user)
    user.add_role(:admin)
    user
  }

  describe "unknown_error handler" do
    context "when in non-production environment" do
      it "re-raises StandardError so programming bugs surface naturally" do
        sign_in(admin)
        allow_any_instance_of(TasksController).to receive(:set_task).and_raise(StandardError.new("test bug")) # rubocop:disable RSpec/AnyInstance

        expect {
          get task_path(id: 1)
        }.to raise_error(StandardError, "test bug")
      end
    end

    context "when in production environment" do
      it "renders the unknown error page with 500 status" do
        sign_in(admin)
        allow(Rails.env).to receive(:production?).and_return(true)
        allow_any_instance_of(TasksController).to receive(:set_task).and_raise(StandardError.new("production bug")) # rubocop:disable RSpec/AnyInstance

        get task_path(id: 1)

        expect(response).to have_http_status(:internal_server_error)
        expect(response).to render_template("errors/unknown_error")
      end

      it "renders JSON error for JSON requests" do
        sign_in(admin)
        allow(Rails.env).to receive(:production?).and_return(true)
        allow_any_instance_of(TasksController).to receive(:set_task).and_raise(StandardError.new("production bug")) # rubocop:disable RSpec/AnyInstance

        get task_path(id: 1), headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body["error"]).to eq("Unknown Error")
      end
    end
  end
end
