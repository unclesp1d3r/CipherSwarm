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

  # Retrieves a cracked hash list associated with a task, marking the task as not stale
  # and sending the cracked list data as a downloadable file. The task is identified
  # by the provided ID.
  #
  # If the task is not found, a 404 Not Found status is rendered. If the task is already
  # completed, an error message is returned with an unprocessable entity status.
  #
  # @return [void]
  def get_zaps
    # A `zap` is a hash that has been cracked through some other means and should be removed from the task's workload.
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

  # Submits a crack result for a specific task, updating the relevant hash item and task state.
  # If the task or hash item is not found, or if updates fail, appropriate error responses are rendered.
  # Also updates related hash items with the same hash value and handles task completion.
  #
  # @return [nil] if any error occurs or when completing the process successfully. Renders appropriate responses.
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

    HashItem.transaction do
      unless hash_item.update(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: task.attack)
        render json: hash_item.errors, status: :unprocessable_entity
        return
      end

      unless task.accept_crack
        render json: task.errors, status: :unprocessable_entity
        return
      end

      # Update any other hash items with the same hash value that are not cracked
      HashItem.includes(:hash_list).where(hash_value: hash_item.hash_value, cracked: false, hash_list: { hash_type_id: hash_list.hash_type_id }).
        update!(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: task.attack)

      # If there is another task for the same hash list, they should be made stale.
      task.hash_list.campaigns.each { |c| c.attacks.each { |a| a.tasks.where.not(id: task.id).update(stale: true) } }
    end

    @message = "Hash cracked successfully, #{hash_list.uncracked_count} hashes remaining, task #{task.state}."
    task.attack.campaign.touch # rubocop: disable Rails/SkipsModelValidations
    return unless task.completed?
    render status: :no_content
  end

  # Handles the submission of the current task's status.
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
    guess_params = status_params[:hashcat_guess]
    if guess_params.present?
      status.hashcat_guess = HashcatGuess.new(guess_params)
    else
      render json: { error: "Guess not found" }, status: :unprocessable_entity
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

  private

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
