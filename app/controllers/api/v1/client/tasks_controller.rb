# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Api::V1::Client::TasksController
#
# This controller is part of the API v1 for managing tasks associated
# with a client. It inherits functionality from Api::V1::BaseController.
#
# == Fields
# - +message+:: A field representing a message associated with the tasks.
# - +task+:: The task object managed within the controller functions.
# - +agent+:: The agent object related to a task's operations.
#
# == Methods
# - +show+:: Fetch and display the details of a specific task.
# - +new+:: Create and initialize a new task.
# - +abandon+:: Handle the logic for abandoning a task.
# - +accept_task+:: Manage the operation of accepting a specific task.
# - +exhausted+:: Mark a task as exhausted, typically when resources or limits are reached.
# - +get_zaps+:: Retrieve specific information or actions related to "zaps".
# - +submit_crack+:: Submit data or statuses related to task cracking operations.
# - +submit_status+:: Update or submit the current status of the task.
#
# This controller makes use of various modules and components to provide
# functionality consistent with the Rails MVC framework. These include
# routing helpers, rendering methods, and other actionable controller features.
class Api::V1::Client::TasksController < Api::V1::BaseController
  before_action :set_task, only: %i[show abandon accept_task exhausted get_zaps submit_crack submit_status]

  # Retrieves a specific task for the agent based on the provided ID.
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # @return [nil]
  def show
    log_task_access(@agent.id, @task.id, { method: request.method, path: request.path }, true)
    # Render using Jbuilder template (show.json.jbuilder)
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
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # This action abandons a task. If the task cannot be abandoned,
  # it responds with a 422 Unprocessable Entity status and includes the task's errors in the response.
  #
  # @return [void]
  def abandon
    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Abandoning task")

    if @task.abandon
      log_task_state_change(
        task_id: @task.id,
        agent_id: @agent.id,
        attack_id: @task.attack_id,
        from_state: @task.state_was,
        to_state: @task.state,
        context: { action: "abandoned" }
      )
      render json: { success: true, state: @task.state }, status: :ok
    else
      Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to abandon: #{@task.errors.full_messages}")
      render json: { error: "Failed to abandon task", details: @task.errors.full_messages },
             status: :unprocessable_content
    end
  end

  # Accepts a task for the current agent.
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # This method attempts to accept a task for the current agent based on the provided task ID.
  # If the task is already completed, it returns a 422 Unprocessable Entity status with an error message.
  # If the task cannot be accepted due to validation errors, it returns a 422 Unprocessable Entity status with the errors.
  #
  # @return [void]
  def accept_task
    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Accepting task")

    if @task.completed?
      Rails.logger.warn("[Agent #{@agent.id}] Task #{@task.id} - Cannot accept: already completed")
      render json: { error: "Task already completed" }, status: :unprocessable_content
      return
    end

    unless @task.accept
      Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to accept: #{@task.errors.full_messages}")
      render json: { error: "Failed to accept task", details: @task.errors.full_messages },
             status: :unprocessable_content
      return
    end

    log_task_state_change(
      task_id: @task.id,
      agent_id: @agent.id,
      attack_id: @task.attack_id,
      from_state: @task.state_was,
      to_state: @task.state,
      context: { action: "accepted" }
    )

    unless @task.attack.accept
      Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to accept attack #{@task.attack.id}: #{@task.attack.errors.full_messages}")
      render json: { error: "Failed to start attack", details: @task.attack.errors.full_messages },
             status: :unprocessable_content
      return
    end

    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Successfully accepted")
    head :no_content
  end

  # Handles the exhaustion of a task.
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # This action marks a task as exhausted.
  # If the task cannot be exhausted, it responds with a 422 Unprocessable Entity status and the task's errors.
  # If the task's associated attack cannot be exhausted, it also responds with a 422 Unprocessable Entity status and the task's errors.
  #
  # @return [void]
  def exhausted
    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Marking task as exhausted")

    unless @task.exhaust
      Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to exhaust: #{@task.errors.full_messages}")
      render json: @task.errors, status: :unprocessable_content
      return
    end

    log_task_state_change(
      task_id: @task.id,
      agent_id: @agent.id,
      attack_id: @task.attack_id,
      from_state: @task.state_was,
      to_state: @task.state,
      context: { action: "exhausted" }
    )

    unless @task.attack.exhaust
      Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to exhaust attack: #{@task.errors.full_messages}")
      render json: @task.errors, status: :unprocessable_content
      return
    end

    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Successfully exhausted")
    head :no_content
  end

  # Retrieves a cracked hash list associated with a task, marking the task as not stale
  # and sending the cracked list data as a downloadable file.
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # If the task is already completed, an error message is returned with an unprocessable entity status.
  #
  # @return [void]
  def get_zaps
    # A `zap` is a hash that has already been cracked. This method retrieves the cracked hash list
    # so the agent can exclude these hashes from its workload.
    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Retrieving zaps (cracked hashes)")

    if @task.completed?
      Rails.logger.warn("[Agent #{@agent.id}] Task #{@task.id} - Cannot get zaps: task already completed")
      render json: { error: "Task already completed" }, status: :unprocessable_content
      return
    end

    @task.update(stale: false)
    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Sending cracked hash list")
    send_data @task.attack.campaign.hash_list.cracked_list,
              filename: "#{@task.attack.campaign.hash_list.id}.txt"
  end

  # Submits a crack result for a specific task, updating the relevant hash item and task state.
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # If the hash item is not found, or if updates fail, appropriate error responses are rendered.
  # Also updates related hash items with the same hash value and handles task completion.
  #
  # @return [nil] if any error occurs or when completing the process successfully. Renders appropriate responses.
  def submit_crack
    timestamp = params[:timestamp]
    hash = params[:hash]
    plain_text = params[:plain_text]

    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Submitting crack for hash: #{hash[0..15]}...")

    hash_list = @task.hash_list
    hash_item = hash_list.hash_items.where(hash_value: hash).first
    if hash_item.blank?
      Rails.logger.warn("[Agent #{@agent.id}] Task #{@task.id} - Hash not found: #{hash[0..15]}...")
      render json: { error: "Hash not found" }, status: :not_found
      return
    end

    HashItem.transaction do
      unless hash_item.update(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: @task.attack)
        Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to update hash item: #{hash_item.errors.full_messages}")
        render json: hash_item.errors, status: :unprocessable_content
        return
      end

      unless @task.accept_crack
        Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to accept crack: #{@task.errors.full_messages}")
        render json: @task.errors, status: :unprocessable_content
        return
      end

      # Update any other hash items with the same hash value that are not cracked
      HashItem.includes(:hash_list).where(hash_value: hash_item.hash_value, cracked: false, hash_list: { hash_type_id: hash_list.hash_type_id }).
        update!(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: @task.attack)

      # If there is another task for the same hash list, they should be made stale.
      @task.hash_list.campaigns.each { |c| c.attacks.each { |a| a.tasks.where.not(id: @task.id).update(stale: true) } }
    end

    uncracked_count = hash_list.uncracked_count
    Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Hash cracked successfully, #{uncracked_count} hashes remaining, task state: #{@task.state}")
    @message = "Hash cracked successfully, #{uncracked_count} hashes remaining, task #{@task.state}."
    @task.attack.campaign.touch # rubocop: disable Rails/SkipsModelValidations
    return unless @task.completed?
    render status: :no_content
  end

  # Handles the submission of the current task's status.
  # Task lookup and error handling is performed by the set_task before_action.
  #
  # This method updates the task's activity timestamp and creates a new status with the provided parameters.
  # If provided, the method processes hashcat guesses and device statuses to associate with the status.
  # The task's state is further updated based on the submitted status. If validation errors occur
  # during processing, appropriate error responses are returned.
  #
  # @return [nil] if the task's state is updated successfully, indicated by HTTP status codes: 204 (No Content),
  #   202 (Accepted) for stale tasks, or 410 (Gone) for paused tasks.
  # @return [Hash] an error response with validation messages and an HTTP status code of 422
  #   (Unprocessable Entity), if the creation of hashcat guesses or device statuses fails.
  def submit_status
    Rails.logger.debug { "[Agent #{@agent.id}] Task #{@task.id} - Submitting status update" }
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
    guess_params = status_params[:hashcat_guess]
    if guess_params.present?
      status.hashcat_guess = HashcatGuess.new(guess_params)
    else
      Rails.logger.warn("[Agent #{@agent.id}] Task #{@task.id} - Guess parameters not found in status update")
      render json: { error: "Guess not found" }, status: :unprocessable_content
      return
    end

    # Get the device statuses from the status and create them if they exist
    device_statuses = status_params[:device_statuses] || status_params[:devices] # Support old and new names
    if device_statuses.present?
      device_statuses.each do |device_status_params|
        device_status = DeviceStatus.new(device_status_params)
        status.device_statuses << device_status
      end
    else
      Rails.logger.warn("[Agent #{@agent.id}] Task #{@task.id} - Device statuses not found in status update")
      render json: { error: "Device Statuses not found" }, status: :unprocessable_content
      return
    end

    unless status.save
      Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to save status: #{status.errors.full_messages}")
      render json: status.errors, status: :unprocessable_content
      return
    end

    # Update the task's state based on the status and return no_content if the state was updated
    if @task.accept_status
      if @task.stale
        Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Status accepted, task is stale")
        return head :accepted
      end
      if @task.paused?
        Rails.logger.info("[Agent #{@agent.id}] Task #{@task.id} - Status accepted, task is paused")
        return head :gone
      end
      Rails.logger.debug { "[Agent #{@agent.id}] Task #{@task.id} - Status update successful" }
      return head :no_content
    end

    # If the state was not updated, return the task's errors
    Rails.logger.error("[Agent #{@agent.id}] Task #{@task.id} - Failed to accept status: #{@task.errors.full_messages}")
    render json: @task.errors, status: :unprocessable_content
  end

  private

  # Finds and sets the @task instance variable for the current agent.
  # This method is used as a before_action callback to ensure tasks exist and belong to the agent.
  # If the task is not found, it uses enhanced error handling from TaskErrorHandling concern.
  #
  # @return [void]
  def set_task
    @task = @agent.tasks.find(params[:id])
    log_task_access(@agent.id, params[:id], { method: request.method, path: request.path }, true)
  rescue ActiveRecord::RecordNotFound
    log_task_access(@agent.id, params[:id], { method: request.method, path: request.path }, false)
    error_response = handle_task_not_found(params[:id], @agent)
    render json: error_response, status: :not_found
  end

  # Strong parameters for status submission
  def status_params
    params.permit(
      :original_line, :session, :time, :status, :target, :restore_point, :rejected, :time_start, :estimated_stop,
      progress: [], recovered_hashes: [], recovered_salts: [],
      hashcat_guess: %i[
        guess_base guess_base_count guess_base_offset guess_base_percentage
        guess_mod guess_mod_count guess_mod_offset guess_mod_percentage guess_mode
      ],
      device_statuses: %i[device_id device_name device_type speed utilization temperature],
      devices: %i[device_id device_name device_type speed utilization temperature]
    )
  end
end
