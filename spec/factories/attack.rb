# frozen_string_literal: true

# == Schema Information
#
# Table name: operations
#
#  id                                                                                                  :bigint           not null, primary key
#  attack_mode(Hashcat attack mode)                                                                    :integer          default("dictionary"), not null, indexed
#  classic_markov(Is classic Markov chain enabled?)                                                    :boolean          default(FALSE), not null
#  custom_charset_1(Custom charset 1)                                                                  :string           default("")
#  custom_charset_2(Custom charset 2)                                                                  :string           default("")
#  custom_charset_3(Custom charset 3)                                                                  :string           default("")
#  custom_charset_4(Custom charset 4)                                                                  :string           default("")
#  description(Attack description)                                                                     :text             default("")
#  disable_markov(Is Markov chain disabled?)                                                           :boolean          default(FALSE), not null
#  increment_maximum(Hashcat increment maximum)                                                        :integer          default(0)
#  increment_minimum(Hashcat increment minimum)                                                        :integer          default(0)
#  increment_mode(Is the attack using increment mode?)                                                 :boolean          default(FALSE), not null
#  left_rule(Left rule)                                                                                :string           default("")
#  markov_threshold(Hashcat Markov threshold (e.g. 1000))                                              :integer          default(0)
#  mask(Hashcat mask (e.g. ?a?a?a?a?a?a?a?a))                                                          :string           default("")
#  name(Attack name)                                                                                   :string           default(""), not null
#  optimized(Is the attack optimized?)                                                                 :boolean          default(FALSE), not null
#  right_rule(Right rule)                                                                              :string           default("")
#  slow_candidate_generators(Are slow candidate generators enabled?)                                   :boolean          default(FALSE), not null
#  status(Operation status)                                                                            :integer          default("pending"), not null, indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           indexed
#  cracker_id                                                                                          :bigint           indexed
#
# Indexes
#
#  index_operations_on_attack_mode  (attack_mode)
#  index_operations_on_campaign_id  (campaign_id)
#  index_operations_on_cracker_id   (cracker_id)
#  index_operations_on_status       (status)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (cracker_id => crackers.id)
#
FactoryBot.define do
  factory :attack do
    name
    workload_profile { 3 }
    optimized { true }
    campaign

    factory :dictionary_attack do
      attack_mode { :dictionary }
      word_lists { create_list(:word_list, 1) }
    end

    factory :combination_attack do
      attack_mode { :combinator }
      word_lists { create_list(:word_list, 2) }
      left_rule { "l" }
      right_rule { "r" }
    end

    factory :mask_attack do
      attack_mode { :mask }
      mask { "?a?a?a?a?a?a?a?a" }
    end

    factory :increment_attack do
      attack_mode { :mask }
      increment_mode { true }
      mask { "?a?a?a?a?a?a?a?a" }
    end

    factory :hybrid_dictionary_attack do
      attack_mode { :hybrid_dictionary }
      mask { "?a?a?a?a?a?a?a?a" }
      word_lists { create_list(:word_list, 1) }
    end

    factory :hybrid_mask_attack do
      attack_mode { :hybrid_mask }
      mask { "?a?a?a?a?a?a?a?a" }
      word_lists { create_list(:word_list, 1) }
    end
  end
end
