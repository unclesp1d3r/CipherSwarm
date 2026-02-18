# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "cancan/matchers"

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project) }
  let(:other_project) { create(:project) }

  describe "Agent permissions" do
    let(:own_agent) { create(:agent, user: user) }
    let(:other_agent) { create(:agent, user: other_user, projects: [other_project]) }
    let(:project_agent) { create(:agent, user: other_user, projects: [project]) }

    before do
      create(:project_user, user: user, project: project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:create, Agent) }
      it { is_expected.to be_able_to(:read, own_agent) }
      it { is_expected.to be_able_to(:update, own_agent) }
      it { is_expected.to be_able_to(:destroy, own_agent) }

      it { is_expected.not_to be_able_to(:read, other_agent) }
      it { is_expected.not_to be_able_to(:update, other_agent) }
      it { is_expected.not_to be_able_to(:destroy, other_agent) }

      it { is_expected.to be_able_to(:read, project_agent) }
      it { is_expected.not_to be_able_to(:update, project_agent) }
      it { is_expected.not_to be_able_to(:destroy, project_agent) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, Agent) }
      it { is_expected.to be_able_to(:create, own_agent) }
      it { is_expected.to be_able_to(:read, own_agent) }
      it { is_expected.to be_able_to(:update, own_agent) }
      it { is_expected.to be_able_to(:destroy, own_agent) }
      it { is_expected.to be_able_to(:read, other_agent) }
      it { is_expected.to be_able_to(:update, other_agent) }
      it { is_expected.to be_able_to(:destroy, other_agent) }
    end

    context "when user is nil" do
      subject(:ability) { described_class.new(nil) }

      it { is_expected.not_to be_able_to(:create, Agent) }
      it { is_expected.not_to be_able_to(:read, own_agent) }
      it { is_expected.not_to be_able_to(:update, own_agent) }
      it { is_expected.not_to be_able_to(:destroy, own_agent) }
    end
  end

  describe "Campaign permissions" do
    let(:project_campaign) { create(:campaign, project: project) }
    let(:other_campaign) { create(:campaign, project: other_project) }

    before do
      create(:project_user, user: user, project: project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:create, Campaign) }
      it { is_expected.to be_able_to(:manage, project_campaign) }
      it { is_expected.not_to be_able_to(:manage, other_campaign) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, Campaign) }
      it { is_expected.to be_able_to(:manage, project_campaign) }
      it { is_expected.to be_able_to(:manage, other_campaign) }
    end
  end

  describe "Project permissions" do
    let(:user_project) { create(:project) }
    let(:other_project) { create(:project) }

    before do
      create(:project_user, user: user, project: user_project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:read, user_project) }
      it { is_expected.not_to be_able_to(:read, other_project) }
      it { is_expected.not_to be_able_to(:update, user_project) }
      it { is_expected.not_to be_able_to(:destroy, user_project) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, Project) }
      it { is_expected.to be_able_to(:read, user_project) }
      it { is_expected.to be_able_to(:read, other_project) }
    end
  end

  describe "Attack resource permissions (WordList, RuleList, MaskList)" do
    let(:public_word_list) { create(:word_list, sensitive: false) }
    let(:sensitive_word_list) { create(:word_list, sensitive: true, projects: [project]) }
    let(:user_word_list) { create(:word_list, creator: user) }
    let(:other_word_list) { create(:word_list, sensitive: true, projects: [other_project]) }

    before do
      create(:project_user, user: user, project: project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:read, public_word_list) }
      it { is_expected.to be_able_to(:create, WordList) }
      it { is_expected.to be_able_to(:view_file, public_word_list) }
      it { is_expected.to be_able_to(:view_file_content, public_word_list) }

      it { is_expected.to be_able_to(:manage, sensitive_word_list) }
      it { is_expected.to be_able_to(:manage, user_word_list) }
      it { is_expected.not_to be_able_to(:read, other_word_list) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, public_word_list) }
      it { is_expected.to be_able_to(:manage, sensitive_word_list) }
      it { is_expected.to be_able_to(:manage, user_word_list) }
      it { is_expected.to be_able_to(:manage, other_word_list) }
    end
  end

  describe "HashList permissions" do
    let(:project_hash_list) { create(:hash_list, project: project) }
    let(:other_hash_list) { create(:hash_list, project: other_project) }

    before do
      create(:project_user, user: user, project: project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:manage, project_hash_list) }
      it { is_expected.not_to be_able_to(:manage, other_hash_list) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, project_hash_list) }
      it { is_expected.to be_able_to(:manage, other_hash_list) }
    end
  end

  describe "Attack permissions" do
    let(:project_campaign) { create(:campaign, project: project) }
    let(:other_campaign) { create(:campaign, project: other_project) }
    let(:project_attack) { create(:attack, campaign: project_campaign) }
    let(:other_attack) { create(:attack, campaign: other_campaign) }

    before do
      create(:project_user, user: user, project: project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:manage, project_attack) }
      it { is_expected.not_to be_able_to(:manage, other_attack) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, project_attack) }
      it { is_expected.to be_able_to(:manage, other_attack) }
    end
  end

  describe "Task permissions" do
    let(:project_campaign) { create(:campaign, project: project) }
    let(:other_campaign) { create(:campaign, project: other_project) }
    let(:project_attack) { create(:attack, campaign: project_campaign) }
    let(:other_attack) { create(:attack, campaign: other_campaign) }
    let(:project_task) { create(:task, attack: project_attack) }
    let(:other_task) { create(:task, attack: other_attack) }

    before do
      create(:project_user, user: user, project: project)
    end

    context "when user is regular user" do
      it { is_expected.to be_able_to(:read, project_task) }
      it { is_expected.to be_able_to(:cancel, project_task) }
      it { is_expected.to be_able_to(:retry, project_task) }
      it { is_expected.to be_able_to(:reassign, project_task) }
      it { is_expected.to be_able_to(:download_results, project_task) }
      it { is_expected.not_to be_able_to(:read, other_task) }
      it { is_expected.not_to be_able_to(:cancel, other_task) }
      it { is_expected.not_to be_able_to(:retry, other_task) }
      it { is_expected.not_to be_able_to(:reassign, other_task) }
      it { is_expected.not_to be_able_to(:download_results, other_task) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, project_task) }
      it { is_expected.to be_able_to(:manage, other_task) }
      it { is_expected.to be_able_to(:cancel, project_task) }
      it { is_expected.to be_able_to(:retry, other_task) }
      it { is_expected.to be_able_to(:reassign, project_task) }
      it { is_expected.to be_able_to(:download_results, other_task) }
    end
  end

  describe "User permissions" do
    context "when user is regular user" do
      it { is_expected.to be_able_to(:read, user) }
      it { is_expected.not_to be_able_to(:read, other_user) }
      it { is_expected.not_to be_able_to(:update, user) }
      it { is_expected.not_to be_able_to(:destroy, user) }
    end

    context "when user is admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:manage, User) }
      it { is_expected.to be_able_to(:read, user) }
      it { is_expected.to be_able_to(:read, other_user) }
      it { is_expected.to be_able_to(:read, :admin_dashboard) }
    end
  end

  describe "High priority campaign permissions" do
    let(:project_campaign) { create(:campaign, project: project) }
    let(:other_campaign) { create(:campaign, project: other_project) }
    let(:project_admin) { create(:user) }
    let(:project_owner) { create(:user) }

    before do
      create(:project_user, user: user, project: project, role: :viewer)
      create(:project_user, user: project_admin, project: project, role: :admin)
      create(:project_user, user: project_owner, project: project, role: :owner)
    end

    context "when user is regular project member" do
      it { is_expected.not_to be_able_to(:set_high_priority, project_campaign) }
      it { is_expected.not_to be_able_to(:set_high_priority, other_campaign) }
    end

    context "when user is project admin" do
      subject(:ability) { described_class.new(project_admin) }

      it { is_expected.to be_able_to(:set_high_priority, project_campaign) }
      it { is_expected.not_to be_able_to(:set_high_priority, other_campaign) }
    end

    context "when user is project owner" do
      subject(:ability) { described_class.new(project_owner) }

      it { is_expected.to be_able_to(:set_high_priority, project_campaign) }
      it { is_expected.not_to be_able_to(:set_high_priority, other_campaign) }
    end

    context "when user is global admin" do
      subject(:ability) { described_class.new(admin) }

      it { is_expected.to be_able_to(:set_high_priority, project_campaign) }
      it { is_expected.to be_able_to(:set_high_priority, other_campaign) }
    end
  end
end
