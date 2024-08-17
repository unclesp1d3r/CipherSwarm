# frozen_string_literal: true

# == Schema Information
#
# Table name: mask_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the mask list)    :text
#  line_count(Number of lines in the mask list) :bigint
#  name(Name of the mask list)                  :string(255)      not null, indexed
#  processed(Has the mask list been processed?) :boolean          default(FALSE), not null, indexed
#  sensitive(Is the mask list sensitive?)       :boolean          default(FALSE), not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_mask_lists_on_name       (name) UNIQUE
#  index_mask_lists_on_processed  (processed)
#
class MaskList < ApplicationRecord
  include AttackResource
end
