# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: users
#
#  id                                                :bigint           not null, primary key
#  auth_migrated                                     :boolean          default(FALSE), not null, indexed
#  current_sign_in_at                                :datetime
#  current_sign_in_ip                                :string
#  email                                             :string(50)       default(""), not null, uniquely indexed
#  encrypted_password                                :string           default(""), not null
#  failed_attempts                                   :integer          default(0), not null
#  last_sign_in_at                                   :datetime
#  last_sign_in_ip                                   :string
#  locked_at                                         :datetime
#  name(Unique username. Used for login.)            :string           not null, uniquely indexed
#  password_digest                                   :string
#  remember_created_at                               :datetime
#  reset_password_sent_at                            :datetime
#  reset_password_token                              :string           uniquely indexed
#  role(The role of the user, either basic or admin) :integer          default(0)
#  sign_in_count                                     :integer          default(0), not null
#  unlock_token                                      :string           uniquely indexed
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#
# Indexes
#
#  index_users_on_auth_migrated         (auth_migrated)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_name                  (name) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
require "rails_helper"
require "cancan/matchers"

RSpec.describe User do
  describe "validations" do
    subject { create(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_confirmation_of(:password) }
    it { is_expected.to normalize(:email).from("TEST@test.com ").to("test@test.com") }
  end

  describe "associations" do
    it { is_expected.to have_many(:agents) }
    it { is_expected.to have_many(:project_users).dependent(:destroy) }
    it { is_expected.to have_many(:projects).through(:project_users) }
    it { is_expected.to have_many(:mask_lists).with_foreign_key(:creator_id).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:word_lists).with_foreign_key(:creator_id).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:rule_lists).with_foreign_key(:creator_id).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:campaigns).with_foreign_key(:creator_id).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:hash_lists).with_foreign_key(:creator_id).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:attacks).with_foreign_key(:creator_id).dependent(:restrict_with_error) }
  end

  describe "abilities" do
    let(:user) { create(:user) }
    let(:admin) { create(:admin) }
    let(:project) { create(:project) }

    context "when user is an admin" do
      subject(:ability) { Ability.new(admin) }

      it { is_expected.to be_able_to(:manage, project) }
      it { is_expected.to be_able_to(:manage, create(:campaign, project:)) }
      it { is_expected.to be_able_to(:manage, create(:agent, projects: [project])) }
      it { is_expected.to be_able_to(:update, create(:agent)) }
      it { is_expected.to be_able_to(:manage, create(:dictionary_attack, campaign: create(:campaign, project:))) }
      it { is_expected.to be_able_to(:manage, create(:hash_list, project: project)) }
      it { is_expected.to be_able_to(:manage, create(:mask_list, projects: [project], sensitive: true)) }
      it { is_expected.to be_able_to(:manage, create(:rule_list, projects: [project], sensitive: true)) }
      it { is_expected.to be_able_to(:manage, create(:word_list, projects: [project], sensitive: true)) }

      it { is_expected.to be_able_to(:manage, create(:mask_list, projects: [], sensitive: false)) }
      it { is_expected.to be_able_to(:manage, create(:rule_list, projects: [], sensitive: false)) }
      it { is_expected.to be_able_to(:manage, create(:word_list, projects: [], sensitive: false)) }

      it { is_expected.to be_able_to(:read, create(:mask_list, projects: [], sensitive: false)) }
      it { is_expected.to be_able_to(:read, create(:rule_list, projects: [], sensitive: false)) }
      it { is_expected.to be_able_to(:read, create(:word_list, projects: [], sensitive: false)) }
    end

    context "when user is not an admin or project member" do
      subject(:ability) { Ability.new(user) }

      it { is_expected.not_to be_able_to(:manage, project) }
      it { is_expected.not_to be_able_to(:manage, create(:campaign, project:)) }
      it { is_expected.not_to be_able_to(:manage, create(:agent, projects: [project])) }
      it { is_expected.not_to be_able_to(:update, create(:agent)) }
      it { is_expected.not_to be_able_to(:manage, create(:dictionary_attack, campaign: create(:campaign, project:))) }
      it { is_expected.not_to be_able_to(:manage, create(:hash_list, project: project)) }
      it { is_expected.not_to be_able_to(:manage, create(:mask_list, projects: [project], sensitive: true)) }
      it { is_expected.not_to be_able_to(:manage, create(:rule_list, projects: [project], sensitive: true)) }
      it { is_expected.not_to be_able_to(:manage, create(:word_list, projects: [project], sensitive: true)) }

      it { is_expected.not_to be_able_to(:manage, create(:mask_list, projects: [], sensitive: false)) }
      it { is_expected.not_to be_able_to(:manage, create(:rule_list, projects: [], sensitive: false)) }
      it { is_expected.not_to be_able_to(:manage, create(:word_list, projects: [], sensitive: false)) }

      it { is_expected.to be_able_to(:read, create(:mask_list, projects: [], sensitive: false)) }
      it { is_expected.to be_able_to(:read, create(:rule_list, projects: [], sensitive: false)) }
      it { is_expected.to be_able_to(:read, create(:word_list, projects: [], sensitive: false)) }
    end

    context "when user is part of the project" do
      subject(:ability) { Ability.new(project_user) }

      let(:project_user) { create(:user, projects: [project]) }

      it { is_expected.to be_able_to(:manage, create(:campaign, project:)) }
      it { is_expected.not_to be_able_to(:manage, create(:agent, projects: [project])) }
      it { is_expected.to be_able_to(:update, create(:agent, user: project_user)) }
      it { is_expected.to be_able_to(:manage, create(:dictionary_attack, campaign: create(:campaign, project:))) }
      it { is_expected.to be_able_to(:manage, create(:hash_list, project: project)) }
      it { is_expected.to be_able_to(:manage, create(:mask_list, projects: [project], sensitive: true)) }
      it { is_expected.to be_able_to(:manage, create(:rule_list, projects: [project], sensitive: true)) }
      it { is_expected.to be_able_to(:manage, create(:word_list, projects: [project], sensitive: true)) }
    end

    context "when user is the creator of resources" do
      subject(:ability) { Ability.new(creator) }

      let(:creator) { create(:user) }
      let(:other_project) { create(:project) }

      it "can read campaigns they created" do
        campaign = create(:campaign, project: other_project, creator: creator)
        expect(ability).to be_able_to(:read, campaign)
      end

      it "can update campaigns they created" do
        campaign = create(:campaign, project: other_project, creator: creator)
        expect(ability).to be_able_to(:update, campaign)
      end

      it "can destroy campaigns they created" do
        campaign = create(:campaign, project: other_project, creator: creator)
        expect(ability).to be_able_to(:destroy, campaign)
      end

      it "can read hash lists they created" do
        hash_list = create(:hash_list, project: other_project, creator: creator)
        expect(ability).to be_able_to(:read, hash_list)
      end

      it "can update hash lists they created" do
        hash_list = create(:hash_list, project: other_project, creator: creator)
        expect(ability).to be_able_to(:update, hash_list)
      end

      it "can destroy hash lists they created" do
        hash_list = create(:hash_list, project: other_project, creator: creator)
        expect(ability).to be_able_to(:destroy, hash_list)
      end

      it "can read attacks they created" do
        campaign = create(:campaign, project: other_project)
        attack = create(:dictionary_attack, campaign: campaign, creator: creator)
        expect(ability).to be_able_to(:read, attack)
      end

      it "can update attacks they created" do
        campaign = create(:campaign, project: other_project)
        attack = create(:dictionary_attack, campaign: campaign, creator: creator)
        expect(ability).to be_able_to(:update, attack)
      end

      it "can destroy attacks they created" do
        campaign = create(:campaign, project: other_project)
        attack = create(:dictionary_attack, campaign: campaign, creator: creator)
        expect(ability).to be_able_to(:destroy, attack)
      end

      it "cannot manage resources created by others" do
        other_user = create(:user)
        campaign = create(:campaign, project: other_project, creator: other_user)
        expect(ability).not_to be_able_to(:read, campaign)
      end
    end
  end
end
