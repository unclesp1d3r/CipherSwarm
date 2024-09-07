# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                                                :bigint           not null, primary key
#  current_sign_in_at                                :datetime
#  current_sign_in_ip                                :string
#  email                                             :string(50)       default(""), not null, indexed
#  encrypted_password                                :string           default(""), not null
#  failed_attempts                                   :integer          default(0), not null
#  last_sign_in_at                                   :datetime
#  last_sign_in_ip                                   :string
#  locked_at                                         :datetime
#  name(Unique username. Used for login.)            :string           not null, indexed
#  remember_created_at                               :datetime
#  reset_password_sent_at                            :datetime
#  reset_password_token                              :string           indexed
#  role(The role of the user, either basic or admin) :integer          default(0)
#  sign_in_count                                     :integer          default(0), not null
#  unlock_token                                      :string           indexed
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#
# Indexes
#
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
  end
end
