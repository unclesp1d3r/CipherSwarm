# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The CrackersController handles operations related to checking for updates
# and managing cracker-related attributes for client applications under API V1.
class Api::V1::Client::CrackersController < Api::V1::BaseController
  # Checks for updates of a cracker based on the provided version and operating system.
  #
  # Params:
  # - version: The current version of the cracker (String).
  # - operating_system: The operating system for which to check the cracker update (String).
  #
  # Returns:
  # - JSON response containing information about the availability of an update, the latest version, and the download URL.
  #
  def check_for_cracker_update
    current_version = params[:version]
    operating_system = params[:operating_system]

    if current_version.blank? || current_version.nil?
      render json: { error: "Version is required" }, status: :bad_request
      return
    end

    if operating_system.blank? || operating_system.nil?
      render json: { error: "Operating System is required" }, status: :bad_request
      return
    end

    current_semantic_version = CrackerBinary.to_semantic_version(current_version)

    if current_semantic_version.nil?
      render json: { error: "Invalid version format", version: current_version }, status: :bad_request
      return
    end

    # Right now, we only support hashcat as the cracker.
    # In the future, we may support other crackers.
    @updated_cracker = CrackerBinary.check_for_newer(operating_system, current_semantic_version)

    # There are no updated crackers for the specified operating system.
    # It is possible that the operating system is not supported by any crackers.
    # Or the current version is newer than the latest version.
    if @updated_cracker.nil?
      @available = false
      @message = "No updated crackers found for the specified operating system"
      render :check_for_cracker_update
      return
    end

    if @updated_cracker.version == current_version
      @available = false
      @latest_version = @updated_cracker.version
      @download_url = nil
      @exec_name = nil
      @message = "The current version is the latest version"
      render :check_for_cracker_update
      return
    end

    os_entry = @updated_cracker.operating_systems.where(name: params[:operating_system]).first
    @cracker_command = os_entry&.cracker_command
    if @updated_cracker.present?
      @available = true
      @latest_version = @updated_cracker.version
      @download_url = url_for(@updated_cracker.archive_file)
      @exec_name = @cracker_command
      @message = "A newer version of the cracker is available"
    else
      @available = false
      @message = "No updated crackers found for the specified operating system"
    end
    render :check_for_cracker_update
  end

  # Returns the permitted parameters for creating or updating a cracker.
  #
  # Params:
  # - cracker: A hash containing the cracker attributes.
  #
  # Returns:
  # A hash containing the permitted cracker attributes.
  def cracker_params
    params.permit(:name, :version, :archive_file, operating_system_ids: [])
  end
end
