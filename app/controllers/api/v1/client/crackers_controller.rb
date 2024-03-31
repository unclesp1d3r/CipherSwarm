class Api::V1::Client::CrackersController < Api::V1::BaseController
  before_action :set_cracker, only: [ :show ]

  # Retrieves all crackers and renders them as JSON.
  def index
    @crackers = Cracker.all
  end

  # Retrieves a specific cracker and renders it as JSON.
  def show
  end

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
    @assigned_cracker = Cracker.find_by(name: "hashcat")
    @updated_cracker = @assigned_cracker.check_for_newer(operating_system, current_semantic_version)

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

    @cracker_command = @updated_cracker.operating_systems.where(name: params[:operating_system]).first.cracker_command
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
