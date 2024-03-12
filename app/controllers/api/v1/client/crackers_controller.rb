class Api::V1::Client::CrackersController < ApplicationController
  before_action :set_cracker, only: [:show]

  # Retrieves all crackers and renders them as JSON.
  def index
    @crackers = Cracker.all
    render json: @crackers
  end

  # Retrieves a specific cracker and renders it as JSON.
  def show
    render json: @cracker
  end

  # Checks for updates of a cracker based on the provided version and operating system.
  #
  # Params:
  # - current_version: The current version of the cracker (String).
  # - operating_system: The operating system for which to check the cracker update (String).
  #
  # Returns:
  # - JSON response containing information about the availability of an update, the latest version, and the download URL.
  #
  def check_for_cracker_update
    current_version = params[:version]

    if current_version.blank? || current_version.nil?
      render json: { error: "Version is required" }, status: 400
      return
    end

    # The current version of the application.
    # It is modified to remove the leading 'v' if present.
    current_version = current_version.gsub("v", "") if current_version.start_with?("v")

    unless SemVersion.valid?(current_version)
      render json: { error: "Invalid version format", version: current_version }, status: 400
      return
    end

    # Represents a semantic version.
    # A semantic version consists of three parts: major, minor, and patch.
    # It follows the format: MAJOR.MINOR.PATCH.
    semantic_version = SemVersion.new(current_version)
    # Retrieves all crackers that are active and support the specified operating system.
    @possible_crackers = CrackerBinary.includes(:cracker).where(cracker: { name: "hashcat" }).includes(:operating_systems).
      where(active: true, operating_systems: { name: params[:operating_system] }).
      order(created_at: :desc).all

    # If no crackers are found, return an error.
    if @possible_crackers.empty?
      render json: { error: "No crackers found for the specified operating system" }, status: 404
      return
    end

    # Filters the crackers to only include those with a version greater than the current version.
    @possible_crackers = @possible_crackers.all { |cracker| cracker.semantic_version > semantic_version }
    @selected_cracker_binary = @possible_crackers.last

    if @selected_cracker_binary.version == current_version
      render json: { available: false, latest_version: @selected_cracker_binary, download_url: nil, exec_name: nil }
      return
    end
    @cracker_command = @selected_cracker_binary.operating_systems.where(name: params[:operating_system]).first.cracker_command

    render json: { available: @possible_crackers.any?,
                   latest_version: @selected_cracker_binary,
                   download_url: url_for(@selected_cracker_binary.archive_file),
                   exec_name: @cracker_command
    }
  end

  # Returns the permitted parameters for creating or updating a cracker.
  #
  # Params:
  # - cracker: A hash containing the cracker attributes.
  #
  # Returns:
  # A hash containing the permitted cracker attributes.
  def cracker_params
    params.require(:cracker).permit(:name, :version, :archive_file, operating_system_ids: [])
  end

  # Sets the @cracker instance variable by finding the Cracker record with the given ID.
  #
  # Params:
  # - params[:id] (Integer) - The ID of the Cracker record to find.
  #
  # Returns:
  # - None
  def set_cracker
    @cracker = Cracker.find(params[:id])
  end
end
