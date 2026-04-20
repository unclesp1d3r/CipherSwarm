# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: attacks
#
#  id                                                                                                  :bigint           not null, primary key
#  attack_mode(Hashcat attack mode)                                                                    :integer          default("dictionary"), not null, indexed
#  classic_markov(Is classic Markov chain enabled?)                                                    :boolean          default(FALSE), not null
#  complexity_value(Complexity value of the attack)                                                    :decimal(, )      default(0.0), not null, indexed
#  custom_charset_1(Custom charset 1)                                                                  :string           default("")
#  custom_charset_2(Custom charset 2)                                                                  :string           default("")
#  custom_charset_3(Custom charset 3)                                                                  :string           default("")
#  custom_charset_4(Custom charset 4)                                                                  :string           default("")
#  deleted_at                                                                                          :datetime         indexed
#  description(Attack description)                                                                     :text             default("")
#  disable_markov(Is Markov chain disabled?)                                                           :boolean          default(FALSE), not null
#  end_time(The time the attack ended.)                                                                :datetime
#  increment_maximum(Hashcat increment maximum)                                                        :integer          default(0)
#  increment_minimum(Hashcat increment minimum)                                                        :integer          default(0)
#  increment_mode(Is the attack using increment mode?)                                                 :boolean          default(FALSE), not null
#  left_rule(Left rule)                                                                                :string           default("")
#  markov_threshold(Hashcat Markov threshold (e.g. 1000))                                              :integer          default(0)
#  mask(Hashcat mask (e.g. ?a?a?a?a?a?a?a?a))                                                          :string           default("")
#  name(Attack name)                                                                                   :string           default(""), not null
#  optimized(Is the attack optimized?)                                                                 :boolean          default(FALSE), not null
#  priority(The priority of the attack, higher numbers are higher priority.)                           :integer          default(0), not null
#  right_rule(Right rule)                                                                              :string           default("")
#  slow_candidate_generators(Are slow candidate generators enabled?)                                   :boolean          default(FALSE), not null
#  start_time(The time the attack started.)                                                            :datetime
#  state                                                                                               :string           indexed => [campaign_id], indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           not null, indexed, indexed => [state]
#  creator_id(The user who created this attack)                                                        :bigint           indexed
#  mask_list_id(The mask list used for the attack.)                                                    :bigint           indexed
#  rule_list_id(The rule list used for the attack.)                                                    :bigint           indexed
#  word_list_id(The word list used for the attack.)                                                    :bigint           indexed
#
# Indexes
#
#  index_attacks_campaign_id               (campaign_id)
#  index_attacks_on_attack_mode            (attack_mode)
#  index_attacks_on_campaign_id_and_state  (campaign_id,state)
#  index_attacks_on_complexity_value       (complexity_value)
#  index_attacks_on_creator_id             (creator_id)
#  index_attacks_on_deleted_at             (deleted_at)
#  index_attacks_on_mask_list_id           (mask_list_id)
#  index_attacks_on_rule_list_id           (rule_list_id)
#  index_attacks_on_state                  (state)
#  index_attacks_on_word_list_id           (word_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (mask_list_id => mask_lists.id) ON DELETE => cascade
#  fk_rails_...  (rule_list_id => rule_lists.id) ON DELETE => cascade
#  fk_rails_...  (word_list_id => word_lists.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Attack do
  context "with associations" do
    it { is_expected.to belong_to(:campaign) }
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
    it { is_expected.to belong_to(:creator).class_name("User").optional }
  end

  context "with validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:attack_mode) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(65_535) }
    it { is_expected.to validate_presence_of(:workload_profile) }
    it { is_expected.to validate_numericality_of(:workload_profile).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(4) }
    it { is_expected.to validate_length_of(:mask).is_at_most(512).allow_nil }
    it { is_expected.to validate_numericality_of(:increment_minimum).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:increment_maximum).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:markov_threshold).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "dictionary attack mode" do
    # Dictionary Attack specific validations
    # Dictionary attacks require at least one word list
    subject(:dictionary_attack) { build(:dictionary_attack) }

    it { expect(dictionary_attack).to be_valid }
    it { expect(dictionary_attack.attack_mode).to eq("dictionary") }
    it { expect(dictionary_attack.increment_mode).to be_falsey }
    it { expect(dictionary_attack.increment_minimum).to eq(0) }
    it { expect(dictionary_attack.increment_maximum).to eq(0) }
    it { is_expected.to validate_presence_of(:word_list) }
    # it { is_expected.to validate_absence_of(:mask) } # Can't get this to work
  end

  describe "mask attack mode" do
    # Mask Attack specific validations
    # Require a mask
    # Does not allow word lists
    # Does allow increment mode
    # Does not allow rule lists
    subject(:mask_attack) { build(:mask_attack) }

    it { expect(mask_attack).to be_valid }
  end

  describe "mask attack mode with list" do
    subject(:mask_attack) { build(:mask_list_attack) }

    it { expect(mask_attack).to be_valid }
  end

  describe "increment attack mode" do
    # Increment attacks require increment mode
    subject(:increment_attack) { build(:increment_attack) }

    it { expect(increment_attack).to be_valid }
  end

  describe "hybrid dictionary attack mode" do
    # Hybrid Dictionary Attack specific validations
    # Requires a mask
    # Requires a word list
    subject(:hybrid_dictionary_attack) { build(:hybrid_dictionary_attack) }

    it { expect(hybrid_dictionary_attack).to be_valid }
  end

  describe "hybrid mask attack mode" do
    # Hybrid Mask Attack specific validations
    # Requires a mask
    # Requires a word list
    subject(:hybrid_mask_attack) { build(:hybrid_mask_attack) }

    it { expect(hybrid_mask_attack).to be_valid }
  end

  context "with a valid factory" do
    subject(:attack) { build(:dictionary_attack) }

    it { expect(attack).to be_valid }
  end

  context "when deleted" do
    subject(:attack) { build(:dictionary_attack) }

    let!(:child_task) { create(:task, attack: attack) }

    it { expect(child_task).to be_valid }
    it { expect(attack.tasks.count).to eq(1) }
    it { expect { attack.destroy }.to change(Task, :count).by(-1) }
    it { expect { attack.destroy }.to change { Task.unscoped.exists?(child_task.id) }.from(true).to(false) }
  end

  describe "soft delete" do
    subject(:attack) { create(:dictionary_attack) }

    it "sets deleted_at instead of deleting the row" do
      expect { attack.destroy }
        .to change { described_class.unscoped.find(attack.id).deleted_at }.from(nil)
    end

    it "keeps the row in the database after destroy" do
      attack.destroy
      expect(described_class.unscoped.exists?(attack.id)).to be true
    end

    it "excludes discarded records from default queries" do
      attack.destroy
      expect(described_class.all).not_to include(attack)
    end

    it "exposes .kept scope for non-discarded records" do
      other = create(:dictionary_attack)
      attack.destroy
      expect(described_class.kept).to include(other)
      expect(described_class.kept).not_to include(attack)
    end

    it "exposes .discarded scope for soft-deleted records" do
      other = create(:dictionary_attack)
      attack.destroy
      expect(described_class.discarded.pluck(:id)).to contain_exactly(attack.id)
      expect(described_class.discarded).not_to include(other)
    end

    it "reaches discarded records via .unscoped" do
      attack.destroy
      expect(described_class.unscoped.pluck(:id)).to include(attack.id)
    end

    it "answers discarded? true after destroy" do
      attack.destroy
      expect(attack.reload.discarded?).to be true
    end

    it "answers kept? false after destroy" do
      attack.destroy
      expect(attack.reload.kept?).to be false
    end

    it "decrements the campaign.attacks_count counter cache on destroy" do
      campaign = attack.campaign
      create(:dictionary_attack, campaign: campaign)
      expect(campaign.reload.attacks_count).to eq(2)
      attack.destroy
      expect(campaign.reload.attacks_count).to eq(1)
      expect(described_class.unscoped.where(campaign_id: campaign.id).count).to eq(2)
    end

    it "is a no-op when destroy is called on an already-discarded record" do
      attack.destroy
      expect { attack.destroy }.not_to change { attack.reload.deleted_at }
    end

    it "supports destroy! by soft-deleting the record" do
      expect { attack.destroy! }
        .to change { described_class.unscoped.find(attack.id).deleted_at }.from(nil)
      expect(attack.reload.discarded?).to be true
    end

    # Spying on the subject is the correct tool for asserting whether
    # `after_commit` callbacks fire — the cop is over-broad here.
    # rubocop:disable RSpec/SubjectStub
    describe "broadcast guards" do
      it "does not fire after_commit on: :update broadcasters on discard" do
        allow(attack).to receive(:broadcast_attack_progress_update)
        allow(attack).to receive(:clear_campaign_quarantine_if_needed)
        attack.destroy
        expect(attack).not_to have_received(:broadcast_attack_progress_update)
        expect(attack).not_to have_received(:clear_campaign_quarantine_if_needed)
      end

      it "still fires after_commit on: :update broadcasters for normal updates" do
        allow(attack).to receive(:broadcast_attack_progress_update)
        attack.update!(description: "regression guard — normal update still broadcasts")
        expect(attack).to have_received(:broadcast_attack_progress_update).at_least(:once)
      end
    end
    # rubocop:enable RSpec/SubjectStub

    it "raises RecordNotDestroyed from destroy! when discard returns false" do
      allow(attack).to receive(:discard).and_return(false) # rubocop:disable RSpec/SubjectStub
      expect { attack.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed, /Failed to discard Attack/)
    end

    it "exposes nil hash_list through a discarded parent campaign" do
      campaign = attack.campaign
      # Reload the attack through unscoped so default_scope doesn't hide it
      # after the campaign is discarded via the cascade path.
      campaign.destroy
      reloaded = described_class.unscoped.find(attack.id)
      # Campaign is hidden by its default_scope, so the through-association
      # traversal returns nil. Callers iterating unscoped attacks must guard
      # against nil before delegating through #hash_list.
      expect(reloaded.hash_list).to be_nil
    end
  end

  describe "state machine callbacks" do
    describe "abandon error handling" do
      let(:attack) { create(:dictionary_attack, state: "running") }
      let!(:task) { create(:task, attack: attack, state: "running") } # rubocop:disable RSpec/LetSetup

      it "logs error and re-raises when destroy_all fails during abandon" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow(attack.tasks).to receive(:destroy_all).and_raise(StandardError.new("DB connection lost"))

        expect { attack.abandon }.to raise_error(StandardError, "DB connection lost")
        expect(Rails.logger).to have_received(:error).with(/\[AttackAbandon\].*DB connection lost/)
      end

      it "handles errors with nil backtrace" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        error = StandardError.new("No backtrace error")
        allow(error).to receive(:backtrace).and_return(nil)
        allow(attack.tasks).to receive(:destroy_all).and_raise(error)

        expect { attack.abandon }.to raise_error(StandardError, "No backtrace error")
        expect(Rails.logger).to have_received(:error).with(/Not available/)
      end
    end
  end

  describe "SafeBroadcasting integration" do
    let(:attack) { create(:dictionary_attack) }

    it "includes SafeBroadcasting concern" do
      expect(described_class.included_modules).to include(SafeBroadcasting)
    end

    context "when broadcast fails" do
      it "logs BroadcastError without raising" do
        allow(Rails.logger).to receive(:error)
        expect { attack.send(:log_broadcast_error, StandardError.new("Connection refused")) }.not_to raise_error
      end

      it "includes attack ID in broadcast error log" do
        allow(Rails.logger).to receive(:error)
        attack.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/Record ID: #{attack.id}/).at_least(:once)
      end

      it "includes model name in broadcast error log" do
        # Note: Attack is the base class name, not DictionaryAttack (the STI subclass)
        allow(Rails.logger).to receive(:error)
        attack.send(:log_broadcast_error, StandardError.new("Test error"))
        expect(Rails.logger).to have_received(:error).with(/\[BroadcastError\].*Model: Attack/).at_least(:once)
      end
    end
  end

  describe "#pause_tasks" do
    let(:attack) { create(:dictionary_attack, :running) }
    let(:agent) { create(:agent, state: :active) }

    it "pauses non-paused tasks successfully" do
      task = create(:task, attack: attack, agent: agent, state: :running)
      allow(Rails.logger).to receive(:info)

      attack.send(:pause_tasks)

      expect(task.reload.state).to eq("paused")
    end

    it "logs warning when task.pause returns false" do
      task = create(:task, attack: attack, agent: agent, state: :running)
      allow(task).to receive(:pause).and_return(false)
      relation = double("relation") # rubocop:disable RSpec/VerifiedDoubles
      allow(relation).to receive(:find_each).and_yield(task)
      allow(attack).to receive_message_chain(:tasks, :without_state).and_return(relation) # rubocop:disable RSpec/MessageChain
      allow(Rails.logger).to receive(:warn)

      attack.send(:pause_tasks)

      expect(Rails.logger).to have_received(:warn).with(/Failed to pause task #{task.id}/)
    end
  end

  describe "#clear_campaign_quarantine_if_needed" do
    let(:campaign) { create(:campaign) }
    let(:attack) { create(:dictionary_attack, campaign: campaign) }

    before do
      # Set quarantine after all creation callbacks have settled to avoid interference
      campaign.update_columns(quarantined: true, quarantine_reason: "Token length exception") # rubocop:disable Rails/SkipsModelValidations
    end

    it "clears quarantine when word_list_id changes" do
      new_word_list = create(:word_list)
      attack.update!(word_list: new_word_list)

      expect(campaign.reload.quarantined).to be false
      expect(campaign.quarantine_reason).to be_nil
    end

    it "clears quarantine when attack_mode changes" do
      mask_list = create(:mask_list)
      attack.update!(attack_mode: :mask, word_list: nil, mask_list: mask_list, rule_list: nil)

      expect(campaign.reload.quarantined).to be false
    end

    it "clears quarantine when left_rule changes" do
      attack.update!(left_rule: "u")

      expect(campaign.reload.quarantined).to be false
    end

    it "clears quarantine when right_rule changes" do
      attack.update!(right_rule: "l")

      expect(campaign.reload.quarantined).to be false
    end

    it "clears quarantine when markov_threshold changes" do
      attack.update!(markov_threshold: 500)

      expect(campaign.reload.quarantined).to be false
    end

    it "clears quarantine when workload_profile changes" do
      attack.update!(workload_profile: 2)

      expect(campaign.reload.quarantined).to be false
    end

    it "clears quarantine when custom_charset_1 changes" do
      attack.update!(custom_charset_1: "?l?d")

      expect(campaign.reload.quarantined).to be false
    end

    it "clears quarantine when optimized changes" do
      attack.update!(optimized: !attack.optimized)

      expect(campaign.reload.quarantined).to be false
    end

    it "does not clear quarantine when only name changes" do
      attack.update!(name: "Renamed Attack")

      expect(campaign.reload.quarantined).to be true
      expect(campaign.quarantine_reason).to eq("Token length exception")
    end

    it "does not clear quarantine when only description changes" do
      attack.update!(description: "Updated description")

      expect(campaign.reload.quarantined).to be true
    end
  end

  describe "#resume_tasks" do
    let(:attack) { create(:dictionary_attack, :running) }
    let(:agent) { create(:agent, state: :active) }

    it "logs warning when task.resume returns false" do
      task = create(:task, attack: attack, agent: agent, state: :paused, paused_at: 5.minutes.ago)
      allow(task).to receive(:resume).and_return(false)
      allow(attack).to receive_message_chain(:tasks, :find_each).and_yield(task) # rubocop:disable RSpec/MessageChain
      allow(Rails.logger).to receive(:warn)

      attack.send(:resume_tasks)

      expect(Rails.logger).to have_received(:warn).with(/Failed to resume task #{task.id}/)
    end
  end
end
