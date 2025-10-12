# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller responsible for handling attack-related actions for clients
#
# Inherits: Api::V1::BaseController
class Api::V1::Client::AttacksController < Api::V1::BaseController
  # Shows the details of a specific attack.
  #
  # @param [Integer] id The ID of the attack to be shown.
  # @return [void]
  def show
    @attack = Attack.find_by(id: params[:id])
    return if @attack
    render json: { error: "Attack not found." }, status: :not_found
    nil
  end

  # Provides the uncracked hash list for a specific attack.
  #
  # Retrieves the uncracked hash list associated with the campaign of a specific attack
  # and sends it as a downloadable file. If the attack is not found, an error response
  # is rendered with a not found (404) status.
  #
  # @param [Integer] id The ID of the attack whose hash list is to be retrieved.
  # @return [void]
  def hash_list
    @attack = Attack.find(params[:id])
    if @attack.nil?
      render json: { error: "Attack not found." }, status: :not_found
      return
    end
    send_data @attack.campaign.hash_list.uncracked_list,
              filename: "#{@attack.campaign.hash_list.id}.txt"
  end
end
