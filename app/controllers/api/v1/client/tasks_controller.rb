# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

class Api::V1::Client::TasksController < Api::V1::BaseController
  def show
    @task = @agent.tasks.find(params[:id])
  end

  def new
    @task = @agent.new_task
    return unless @task.nil?

    render status: :no_content
  end

  def abandon
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      render status: :not_found
      return
    end

    return if @task.abandon

    render json: @task.errors, status: :unprocessable_entity
  end

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

  def submit_crack
    timestamp = params[:timestamp]
    hash = params[:hash]
    plain_text = params[:plaintext]

    # Find the task on the agent
    task = @agent.tasks.find(params[:id])
    if task.nil?
      render status: :not_found
      return
    end

    hash_list = task.hash_list
    hash_item = hash_list.hash_items.where(hash_value: hash)
    unless hash_item.exists?
      @message = "Hash not found"
      render status: :not_found
      return
    end

    unless hash_item.update(plain_text: plain_text, cracked: true, cracked_time: timestamp)
      render json: { error: "Error updating hash" }, status: :unprocessable_entity
    end
    render json: { error: task.errors.full_messages }, status: :unprocessable_entity unless task.accept_crack
    @message = "Hash cracked successfully, #{hash_list.uncracked_count} hashes remaining, task #{task.state}."

    return unless task.completed?

    render status: :no_content
  end

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
    guess = params[:guess] ||= params[:hashcat_guess] # Support old and new names
    if guess.present?
      status.hashcat_guess = HashcatGuess.build({
                                                  guess_base: guess["guess_base"],
                                                  guess_base_count: guess["guess_base_count"],
                                                  guess_base_offset: guess["guess_base_offset"],
                                                  guess_base_percentage: guess["guess_base_percentage"],
                                                  guess_mod: guess["guess_mod"],
                                                  guess_mod_count: guess["guess_mod_count"],
                                                  guess_mod_offset: guess["guess_mod_offset"],
                                                  guess_mod_percentage: guess["guess_mod_percentage"],
                                                  guess_mode: guess["guess_mode"]
                                                })
    else
      render json: { errors: ["Guess not found"] }, status: :unprocessable_entity
      return
    end

    # Get the device statuses from the status and create them if they exist
    # We need to move this to strong params
    device_statuses = params[:devices] ||= params[:device_statuses] # Support old and new names
    if device_statuses.present?
      device_statuses.each do |device_status|
        device_status = DeviceStatus.build(
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
      render json: { errors: ["Device Statuses not found"] }, status: :unprocessable_entity
      return
    end

    unless status.save
      render json: { errors: status.errors.full_messages }, status: :unprocessable_entity
      return
    end

    # Update the task's state based on the status and return no_content if the state was updated
    return if @task.accept_status

    # If the state was not updated, return the task's errors
    render json: @task.errors, status: :unprocessable_entity
  end

  private

  # def status_params
  #   # params.require(:hashcat_status)
  #   #       .permit(:original_line, :time, :session,
  #   #               :status, :target, :time_start, :rejected, :restore_point,
  #   #               :format, :hashcat_status,
  #   #               :estimated_stop,
  #   #               progress: [], recovered_hashes: [], recovered_salts: [],
  #   #               task: {})
  #   params.require(:hashcat_status).permit(
  #     :original_line,
  #     :time,
  #     :session,
  #     :status,
  #     :target,
  #     :time_start,
  #     :rejected,
  #     :restore_point,
  #     :format,
  #     :hashcat_status,
  #     :estimated_stop,
  #     :task_id,
  #     progress: [],
  #     recovered_hashes: [],
  #     recovered_salts: [],
  #     device_statuses: %i[
  #       device_id
  #       device_name
  #       device_type
  #       speed
  #       util
  #       temp
  #     ],
  #     hashcat_guess: %i[
  #       guess_base
  #       guess_base_count
  #       guess_base_offset
  #       guess_base_percent
  #       guess_mod
  #       guess_mod_count
  #       guess_mod_offset
  #       guess_mod_percent
  #       guess_mode
  #       _destroy
  #     ]
  #   )
  # end
end
