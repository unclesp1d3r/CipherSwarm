# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! @attack,
              :id,
              :attack_mode,
              :mask,
              :increment_mode,
              :increment_minimum,
              :increment_maximum,
              :optimized,
              :slow_candidate_generators,
              :workload_profile,
              :disable_markov,
              :classic_markov,
              :markov_threshold,
              :left_rule,
              :right_rule,
              :custom_charset_1,
              :custom_charset_2,
              :custom_charset_3,
              :custom_charset_4
json.attack_mode_hashcat Attack.attack_modes[@attack.attack_mode]

json.hash_list_id @attack.campaign.hash_list.id

# TODO: Dry this up, since they're all attack resources.
if @attack.word_list
  json.word_list do
    json.id @attack.word_list.id
    json.download_url rails_blob_url(@attack.word_list.file)
    json.checksum @attack.word_list.file.checksum
    json.file_name @attack.word_list.file.filename
  end
else
  json.word_list nil
end

if @attack.rule_list
  json.rule_list do
    json.id @attack.rule_list.id
    json.download_url rails_blob_url(@attack.rule_list.file)
    json.checksum @attack.rule_list.file.checksum
    json.file_name @attack.rule_list.file.filename
  end
else
  json.rule_list nil
end

if @attack.mask_list
  json.mask_list do
    json.id @attack.mask_list.id
    json.download_url rails_blob_url(@attack.mask_list.file)
    json.checksum @attack.mask_list.file.checksum
    json.file_name @attack.mask_list.file.filename
  end
else
  json.mask_list nil
end

json.hash_mode @attack.campaign.hash_list.hash_type.hashcat_mode

# The hash list is dynamically generated from the hash items that have not been cracked yet.
json.hash_list_url api_v1_client_attack_hash_list_url(@attack)

# The hash list checksum is used to determine if the hash list has been updated.
json.hash_list_checksum @attack.campaign.hash_list.uncracked_list_checksum

# The attack URL is used to check the status of the attack.
json.url campaign_attack_url(@attack, format: :json)
