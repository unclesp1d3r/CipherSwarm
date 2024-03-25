class Api::V1::Client::CrackersController < Api::V1::BaseController
  before_action :set_cracker, only: [ :show ]

  resource_description do
    short "Crackers"
    formats [ "json" ]
    desc "The crackers resource allows you to manage the crackers that are available to the agents."
    error 400, "Bad request. The request was invalid."
    error 401, "Unauthorized. The request was not authorized."
    error 404, "Not found. The requested resource was not found."
    header "Authorization", "The token to authenticate the agent with.", required: true
  end

  def_param_group :cracker_update do
    property :available, [ true, false ], desc: "Indicates whether an update is available."
    property :latest_version, String, desc: "The latest version of the cracker."
    property :download_url, String, desc: "The URL to download the latest version of the cracker."
    property :exec_name, String, desc: "The name of the cracker executable."
    property :message, String, desc: "A message indicating the status of the cracker update."
  end

  def_param_group :cracker do
    property :id, Integer, desc: "The unique identifier of the cracker."
    property :name, String, desc: "The name of the cracker."
    property :version, String, desc: "The version of the cracker."
    property :archive_file, String, desc: "The URL to download the cracker archive."
    property :operating_systems, Array, desc: "The operating systems for which the cracker is available."
  end

  # Retrieves all crackers and renders them as JSON.
  api! "Retrieves all crackers."
  returns array_of: :cracker, desc: "The crackers were successfully retrieved."

  def index
    @crackers = Cracker.all
  end

  # Retrieves a specific cracker and renders it as JSON.
  api! "Retrieves the cracker with the specified ID."
  param :id, :number, required: true, desc: "The ID of the cracker to retrieve."
  returns code: 200, desc: "The cracker was successfully retrieved." do
    param_group :cracker
  end

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
  api! "Checks for updates of a cracker based on the provided version and operating system."
  param :version, CrackerBinary.version_regex, required: true, desc: "The current version of the cracker. This must be in semantic version format."
  param :operating_system, String, required: true, desc: "The operating system for which to check the cracker update."
  returns desc: "The cracker update information was successfully retrieved." do
    param_group :cracker_update
  end
  returns code: 400, desc: "The request was invalid." do
    property :error, String, desc: "The error message."
  end
  returns code: 204, desc: "No updated crackers found for the specified operating system." do
    property :available, [ false ], desc: "Indicates whether an update is available."
    property :message, String, desc: "A message indicating the status of the cracker update."
  end

  def check_for_cracker_update
    current_version = params[:version]

    if current_version.blank? || current_version.nil?
      render json: { error: "Version is required" }, status: 400
      return
    end

    current_semantic_version = CrackerBinary.to_semantic_version(current_version)

    if current_semantic_version.nil?
      render json: { error: "Invalid version format", version: current_version }, status: 400
      return
    end

    # Right now, we only support hashcat as the cracker.
    # In the future, we may support other crackers.
    @assigned_cracker = Cracker.find_by(name: "hashcat")
    @updated_cracker = @assigned_cracker.check_for_newer(params[:operating_system], current_semantic_version)

    # There are no updated crackers for the specified operating system.
    # It is possible that the operating system is not supported by any crackers.
    # Or the current version is newer than the latest version.
    if @updated_cracker.nil?
      render json: { available: false, message: "No crackers found for the specified operating system" }, status: 204
      return
    end

    if @updated_cracker.version == current_version
      render json: {
        available: false,
        latest_version: @updated_cracker,
        download_url: nil,
        exec_name: nil,
        message: "The current version is the latest version"
      }
      return
    end

    @cracker_command = @updated_cracker.operating_systems.where(name: params[:operating_system]).first.cracker_command

    render json: { available: true,
                   latest_version: @updated_cracker.version,
                   download_url: url_for(@updated_cracker.archive_file),
                   exec_name: @cracker_command,
                   message: "A newer version of the cracker is available"
    } if @updated_cracker
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
