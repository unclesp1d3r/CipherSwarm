# frozen_string_literal: true


# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0


# Controller for handling attack-related actions for the client in the API.
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

  # Sends the hash list of a specific attack's campaign.
  #
  # @param [Integer] id The ID of the attack whose hash list is to be sent.
  # @return [void]
  # @render [JSON] Renders an error message if the attack is not found.
  # @send_data [String] Sends the uncracked hash list as a text file.
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
