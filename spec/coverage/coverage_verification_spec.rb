# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Coverage Verification" do # rubocop:disable RSpec/DescribeClass
  describe "controller coverage" do
    it "TasksController has request specs" do
      expect(Rails.root.join("spec/requests/tasks_spec.rb").exist?).to be(true)
    end

    it "SystemHealthController has request specs" do
      expect(Rails.root.join("spec/requests/system_health_spec.rb").exist?).to be(true)
    end

    it "CampaignsController has request specs" do
      expect(Rails.root.join("spec/requests/campaigns_spec.rb").exist?).to be(true)
    end

    it "AgentsController has request specs" do
      expect(Rails.root.join("spec/requests/agents_spec.rb").exist?).to be(true)
    end
  end

  describe "component coverage" do
    it "TaskActionsComponent has component specs" do
      expect(Rails.root.join("spec/components/task_actions_component_spec.rb").exist?).to be(true)
    end

    it "CampaignProgressComponent has component specs" do
      expect(Rails.root.join("spec/components/campaign_progress_component_spec.rb").exist?).to be(true)
    end

    it "AgentStatusCardComponent has component specs" do
      expect(Rails.root.join("spec/components/agent_status_card_component_spec.rb").exist?).to be(true)
    end

    it "SystemHealthCardComponent has component specs" do
      expect(Rails.root.join("spec/components/system_health_card_component_spec.rb").exist?).to be(true)
    end

    it "ErrorModalComponent has component specs" do
      expect(Rails.root.join("spec/components/error_modal_component_spec.rb").exist?).to be(true)
    end

    it "SkeletonLoaderComponent has component specs" do
      expect(Rails.root.join("spec/components/skeleton_loader_component_spec.rb").exist?).to be(true)
    end

    it "ToastNotificationComponent has component specs" do
      expect(Rails.root.join("spec/components/toast_notification_component_spec.rb").exist?).to be(true)
    end

    it "AgentDetailTabsComponent has component specs" do
      expect(Rails.root.join("spec/components/agent_detail_tabs_component_spec.rb").exist?).to be(true)
    end
  end

  describe "service coverage" do
    it "SystemHealthCheckService has service specs" do
      expect(Rails.root.join("spec/services/system_health_check_service_spec.rb").exist?).to be(true)
    end

    it "CampaignEtaCalculator has service specs" do
      expect(Rails.root.join("spec/services/campaign_eta_calculator_spec.rb").exist?).to be(true)
    end
  end

  describe "system test coverage" do
    it "agent fleet monitoring has system tests" do
      expect(Rails.root.join("spec/system/agents/agent_monitoring_spec.rb").exist?).to be(true)
    end

    it "campaign progress monitoring has system tests" do
      expect(Rails.root.join("spec/system/campaigns/campaign_progress_monitoring_spec.rb").exist?).to be(true)
    end

    it "task management has system tests" do
      expect(Rails.root.join("spec/system/tasks_spec.rb").exist?).to be(true)
    end

    it "system health has system tests" do
      expect(Rails.root.join("spec/system/system_health_spec.rb").exist?).to be(true)
    end

    it "campaign creation has system tests" do
      expect(Rails.root.join("spec/system/campaigns/create_campaign_spec.rb").exist?).to be(true)
    end
  end

  describe "integration test coverage" do
    it "Turbo Stream updates have integration tests" do
      expect(Rails.root.join("spec/requests/turbo_stream_updates_spec.rb").exist?).to be(true)
    end

    it "caching behavior has integration tests" do
      expect(Rails.root.join("spec/requests/caching_spec.rb").exist?).to be(true)
    end

    it "authorization has integration tests" do
      expect(Rails.root.join("spec/requests/authorization_spec.rb").exist?).to be(true)
    end
  end

  describe "JavaScript test coverage" do
    it "health_refresh_controller has JavaScript tests" do
      expect(Rails.root.join("spec/javascript/controllers/health_refresh_controller.test.js").exist?).to be(true)
    end

    it "tabs_controller has JavaScript tests" do
      expect(Rails.root.join("spec/javascript/controllers/tabs_controller.test.js").exist?).to be(true)
    end

    it "toast_controller has JavaScript tests" do
      expect(Rails.root.join("spec/javascript/controllers/toast_controller.test.js").exist?).to be(true)
    end
  end

  describe "performance test coverage" do
    it "page load performance tests exist" do
      expect(Rails.root.join("spec/performance/page_load_performance_spec.rb").exist?).to be(true)
    end
  end

  describe "deployment test coverage" do
    it "air-gapped deployment checklist tests exist" do
      expect(Rails.root.join("spec/deployment/air_gapped_checklist_spec.rb").exist?).to be(true)
    end
  end

  describe "coverage threshold enforcement" do
    it "SimpleCov is configured with minimum line coverage of 80%" do
      expect(SimpleCov.minimum_coverage[:line]).to be >= 80
    end

    it "last coverage run meets the >80% line coverage threshold" do
      result_path = Rails.root.join("coverage/.resultset.json")
      skip "No coverage data found; run COVERAGE=true bundle exec rspec first" unless result_path.exist?

      result_hash = JSON.parse(result_path.read)
      covered, relevant = aggregate_line_coverage(result_hash)
      overall_percent = (covered.to_f / relevant * 100).round(2)

      expect(overall_percent).to be > 80,
        "Overall line coverage is #{overall_percent}%, expected >80%"
    end
  end

  describe "all seven flow system tests" do
    it "agent fleet monitoring has system tests" do
      expect(Rails.root.join("spec/system/agent_fleet_monitoring_spec.rb").exist?).to be(true)
    end

    it "campaign progress monitoring has system tests" do
      expect(Rails.root.join("spec/system/campaign_progress_monitoring_spec.rb").exist?).to be(true)
    end

    it "task detail investigation has system tests" do
      expect(Rails.root.join("spec/system/task_detail_investigation_spec.rb").exist?).to be(true)
    end

    it "system health has system tests" do
      expect(Rails.root.join("spec/system/system_health_spec.rb").exist?).to be(true)
    end

    it "campaign creation workflow has system tests" do
      expect(Rails.root.join("spec/system/campaign_creation_workflow_spec.rb").exist?).to be(true)
    end

    it "error investigation has system tests" do
      expect(Rails.root.join("spec/system/error_investigation_spec.rb").exist?).to be(true)
    end

    it "loading feedback patterns has system tests" do
      expect(Rails.root.join("spec/system/loading_feedback_patterns_spec.rb").exist?).to be(true)
    end
  end

  private

  # Parse the SimpleCov .resultset.json and aggregate line coverage across all files.
  # Returns [covered_lines, relevant_lines].
  def aggregate_line_coverage(result_hash)
    covered = 0
    relevant = 0

    result_hash.each_value do |suite|
      file_coverage = suite.dig("coverage") || {}
      file_coverage.each_value do |file_data|
        lines = file_data.is_a?(Hash) ? file_data["lines"] : file_data
        next unless lines.is_a?(Array)

        lines.each do |hits|
          next if hits.nil? # not a relevant line

          relevant += 1
          covered += 1 if hits.positive?
        end
      end
    end

    [covered, relevant]
  end
end
