# frozen_string_literal: true

#
# Api::V1::Client::TasksController
#
# This controller handles various actions related to tasks for a client agent.
#
# Actions:
# - show: Retrieves and displays a specific task.
# - new: Initializes a new task for the agent.
# - abandon: Marks a task as abandoned.
# - accept_task: Accepts a task for the agent.
# - exhausted: Marks a task as exhausted.
# - get_zaps: Returns the cracked hashes for the task in a text file.
# - submit_crack: Submits a cracked hash for a task.
# - submit_status: Submits the status of a task.
#
# Each action performs specific validations and renders appropriate responses
# based on the success or failure of the operations.
class Api::V1::Client::TasksController < Api::V1::BaseController
  # Retrieves a specific task for the agent based on the provided ID.
  # If the task is not found, it renders a 404 Not Found status.
  #
  # @return [nil] if the task is not found
  def show
    @task = @agent.tasks.find(params[:id])
    return unless @task.nil?
    render status: :not_found
    nil
  end

  # Initializes a new task for the agent.
  # If the task is nil, it renders a no content status.
  def new
    @task = @agent.new_task
    return unless @task.nil?
    render status: :no_content
    nil
  end

  # Abandons a task assigned to the current agent.
  #
  # This action finds a task by its ID from the current agent's tasks. If the task is not found,
  # it responds with a 404 Not Found status. If the task is found but cannot be abandoned,
  # it responds with a 422 Unprocessable Entity status and includes the task's errors in the response.
  #
  # @return [void]
  def abandon
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      render status: :not_found
      return
    end

    return if @task.abandon

    render json: @task.errors, status: :unprocessable_entity
  end

  # Accepts a task for the current agent.
  #
  # This method attempts to find and accept a task for the current agent based on the provided task ID.
  # If the task is not found, it returns a 404 Not Found status.
  # If the task is already completed, it returns a 422 Unprocessable Entity status with an error message.
  # If the task cannot be accepted due to validation errors, it returns a 422 Unprocessable Entity status with the errors.
  #
  # @return [void]
  def accept_task
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      # This can happen if the task was deleted before the agent could accept it.
      # Also, if another agent accepted the task before this agent could.
      render status: :not_found
      return
    end
    if @task.completed?
      render json: { error: "Task already completed" }, status: :unprocessable_entity
      return
    end

    render json: @task.errors, status: :unprocessable_entity unless @task.accept
    return if @task.attack.accept

    render json: @task.errors, status: :unprocessable_entity
  end

  # Handles the exhaustion of a task.
  #
  # This action finds a task associated with the current agent using the provided task ID.
  # If the task is not found, it responds with a 404 Not Found status.
  # If the task cannot be exhausted, it responds with a 422 Unprocessable Entity status and the task's errors.
  # If the task's associated attack cannot be exhausted, it also responds with a 422 Unprocessable Entity status and the task's errors.
  #
  # @return [void]
  def exhausted
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      render status: :not_found
      return
    end
    render json: @task.errors, status: :unprocessable_entity unless @task.exhaust
    return if @task.attack.exhaust

    render json: @task.errors, status: :unprocessable_entity
  end

  # Retrieves the zaps for a specific task.
  #
  # This method finds a task by its ID and performs the following actions:
  # - If the task is not found, it returns a 404 Not Found status.
  # - If the task is already completed, it returns a 422 Unprocessable Entity status with an error message.
  # - If the task is found and not completed, it updates the task to mark it as not stale and sends the cracked list data as a file.
  #
  # @return [void]
  def get_zaps
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      render status: :not_found
      return
    end
    if @task.completed?
      render json: { error: "Task already completed" }, status: :unprocessable_entity
      return
    end

    @task.update(stale: false)
    send_data @task.attack.campaign.hash_list.cracked_list,
              filename: "#{@task.attack.campaign.hash_list.id}.txt"
  end

  def submit_crack
    timestamp = params[:timestamp]
    hash = params[:hash]
    plain_text = params[:plain_text]

    # Find the task on the agent
    task = @agent.tasks.find(params[:id])
    if task.nil?
      render json: { error: "Task not found" }, status: :not_found
      return
    end

    hash_list = task.hash_list
    hash_item = hash_list.hash_items.where(hash_value: hash).first
    if hash_item.blank?
      render json: { error: "Hash not found" }, status: :not_found
      return
    end

    unless hash_item.update(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: task.attack)
      render json: hash_item.errors, status: :unprocessable_entity
      return
    end

    unless task.accept_crack
      render json: task.errors, status: :unprocessable_entity
      return
    end

    @message = "Hash cracked successfully, #{hash_list.uncracked_count} hashes remaining, task #{task.state}."

    HashItem.transaction do
      # Update any other hash items with the same hash value that are not cracked
      HashItem.includes(:hash_list).where(hash_value: hash_item.hash_value, cracked: false, hash_list: { hash_type_id: hash_list.hash_type_id }).
        update!(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: task.attack)

      # If there is another task for the same hash list, they should be made stale.
      task.hash_list.campaigns.each { |c| c.attacks.each { |a| a.tasks.where.not(id: task.id).update(stale: true) } }
    end
    return unless task.completed?
    render status: :no_content
  end

  #
  # submit_status
  #
  # This method handles the submission of a task's status update. It performs the following steps:
  # 1. Finds the task associated with the agent using the provided task ID.
  # 2. Updates the task's activity timestamp to the current time.
  # 3. Builds a new HashcatStatus object with the provided parameters.
  # 4. If a hashcat guess is provided, it builds and associates a HashcatGuess object with the status.
  # 5. If device statuses are provided, it builds and associates DeviceStatus objects with the status.
  # 6. Saves the status and handles any validation errors.
  # 7. Updates the task's state based on the status and returns appropriate HTTP status codes.
  #
  # Parameters:
  # - params[:id]: The ID of the task to be updated.
  # - params[:original_line]: The original line of the status.
  # - params[:session]: The session information.
  # - params[:time]: The time of the status.
  # - params[:status]: The status information.
  # - params[:target]: The target information.
  # - params[:progress]: The progress information.
  # - params[:restore_point]: The restore point information.
  # - params[:recovered_hashes]: The recovered hashes information.
  # - params[:recovered_salts]: The recovered salts information.
  # - params[:rejected]: The rejected information.
  # - params[:time_start]: The start time of the status.
  # - params[:estimated_stop]: The estimated stop time of the status.
  # - params[:hashcat_guess]: The hashcat guess information.
  # - params[:device_statuses] or params[:devices]: The device statuses information.
  #
  # Returns:
  # - Renders a JSON response with an error message and status :unprocessable_entity if the guess or device statuses are not found.
  # - Renders a JSON response with the status errors and status :unprocessable_entity if the status fails to save.
  # - Returns HTTP status :accepted if the task is stale.
  # - Returns HTTP status :gone if the task is paused.
  # - Returns HTTP status :no_content if the task's state was updated successfully.
  # - Renders a JSON response with the task's errors and status :unprocessable_entity if the task's state was not updated.
  def submit_status
    @task = @agent.tasks.find(params[:id])
    @task.update(activity_timestamp: Time.zone.now)
    status = @task.hashcat_statuses.build({
                                            original_line: params[:original_line],
                                            session: params[:session],
                                            time: params[:time],
                                            status: params[:status],
                                            target: params[:target],
                                            progress: params[:progress],
                                            restore_point: params[:restore_point],
                                            recovered_hashes: params[:recovered_hashes],
                                            recovered_salts: params[:recovered_salts],
                                            rejected: params[:rejected],
                                            time_start: params[:time_start],
                                            estimated_stop: params[:estimated_stop]
                                          })

    # Get the guess from the status and create it if it exists
    # We need to move this to strong params
    guess = params[:hashcat_guess]
    if guess.present?
      status.hashcat_guess = HashcatGuess.new({
                                                guess_base: guess[:guess_base],
                                                guess_base_count: guess[:guess_base_count],
                                                guess_base_offset: guess[:guess_base_offset],
                                                guess_base_percentage: guess[:guess_base_percentage],
                                                guess_mod: guess[:guess_mod],
                                                guess_mod_count: guess[:guess_mod_count],
                                                guess_mod_offset: guess[:guess_mod_offset],
                                                guess_mod_percentage: guess[:guess_mod_percentage],
                                                guess_mode: guess[:guess_mode]
                                              })
    else
      render json: { error: "Guess not found" }, status: :unprocessable_entity
      return
    end

    # Get the device statuses from the status and create them if they exist
    # We need to move this to strong params
    device_statuses = params[:device_statuses] ||= params[:devices] # Support old and new names
    if device_statuses.present?
      device_statuses.each do |device_status|
        device_status = DeviceStatus.new(
          {
            device_id: device_status[:device_id],
            device_name: device_status[:device_name],
            device_type: device_status[:device_type],
            speed: device_status[:speed],
            utilization: device_status[:utilization],
            temperature: device_status[:temperature]
          }
        )
        status.device_statuses << device_status
      end
    else
      render json: { error: "Device Statuses not found" }, status: :unprocessable_entity
      return
    end

    unless status.save
      render json: status.errors, status: :unprocessable_entity
      return
    end

    # Update the task's state based on the status and return no_content if the state was updated
    if @task.accept_status
      return head :accepted if @task.stale
      return head :gone if @task.paused?
      return head :no_content
    end

    # If the state was not updated, return the task's errors
    render json: @task.errors, status: :unprocessable_entity
  end
end
