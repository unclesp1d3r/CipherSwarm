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

# Helper method to render attack resource details
%w[word_list rule_list mask_list].each do |resource_name|
  resource = @attack.send(resource_name)
  json.set! resource_name do
    if resource
      json.id resource.id
      json.download_url rails_blob_url(resource.file)
      json.checksum resource.file.checksum
      json.file_name resource.file.filename
    else
      json.nil!
    end
  end
end

json.hash_mode @attack.campaign.hash_list.hash_type.hashcat_mode

# The hash list is dynamically generated from the hash items that have not been cracked yet.
json.hash_list_url api_v1_client_attack_hash_list_url(@attack)

# The hash list checksum is used to determine if the hash list has been updated.
json.hash_list_checksum @attack.campaign.hash_list.uncracked_list_checksum

# The attack URL is used to check the status of the attack.
json.url campaign_attack_url(@attack, format: :json)
