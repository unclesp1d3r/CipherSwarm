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

json.hash_list_id @attack.campaign.hash_list.id
json.word_lists @attack.word_lists do |word_list|
  json.id word_list.id
  json.download_url rails_blob_url(word_list.file)
  json.checksum word_list.file.checksum
  json.file_name word_list.file.filename
end
json.rule_lists @attack.rule_lists do |rule_list|
  json.id rule_list.id
  json.download_url rails_blob_url(rule_list.file)
  json.checksum rule_list.file.checksum
  json.file_name rule_list.file.filename
end

# The hash mode is a integer representation of the hash mode enum.
json.hash_mode HashList.hash_modes[@attack.campaign.hash_list.hash_mode]

# The hash list is dynamically generated from the hash items that have not been cracked yet.
json.hash_list_url api_v1_client_attack_hash_list_url(@attack)

# The hash list checksum is used to determine if the hash list has been updated.
json.hash_list_checksum @attack.campaign.hash_list.uncracked_list_checksum

# The attack URL is used to check the status of the attack.
json.url attack_url(@attack, format: :json)
