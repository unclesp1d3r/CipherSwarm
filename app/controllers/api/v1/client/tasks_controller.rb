class Api::V1::Client::TasksController < Api::V1::BaseController # rubocop:disable Metrics/ClassLength
  wrap_parameters HashcatStatus

  def show
    @task = @agent.tasks.find(params[:id])
  end

  def new
    @task = @agent.new_task
    if @task.nil?
      render status: :no_content
    end
  end

  def update
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      render status: :not_found
    end
    if @task.update(task_params)
      render partial: "task", locals: { task: @task }
    else
      render json: @task.errors, status: :unprocessable_entity
    end
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

    if hash_list.uncracked_items.empty?
      @message = "No more uncracked hashes"
      task.update_status
      render status: :no_content
      return
    end

    if hash_item.update(plain_text: plain_text, cracked: true, cracked_time: timestamp)
      task.update(activity_timestamp: Time.zone.now)
      task.update_status
      @message = "Hash cracked successfully"
    else
      render json: { error: "Error updating hash" }, status: :unprocessable_entity
    end
  end

  def accept_task
    update_last_seen
    @task = @agent.tasks.find(params[:id])
    if @task.nil?
      render status: :not_found
      return
    end
    if @task.completed?
      render json: { error: "Task already completed" }, status: :unprocessable_entity
      return
    end

    if @task.update(status: :running, start_date: Time.zone.now, activity_timestamp: Time.zone.now)
      @task.attack.update(status: :running) unless @task.attack.completed?
      @task.update_status
    else
      render json: @task.errors, status: :unprocessable_entity
    end
  end

  def submit_status
    @task = @agent.tasks.find(params[:id])
    @task.update(activity_timestamp: Time.zone.now)
    # @task.update_status
    @task_status = params[:_json]
    status = @task.hashcat_statuses.build(status_params)
    unless status.save!
      render json: { error: status.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def exhausted
    @task = @agent.tasks.find(params[:id])
    if @task.update(status: :exhausted)
      @task.attack.update(status: :completed) if @task.attack.tasks.pending.empty?
      @task.update_status
    end
  end

  private

  def task_params
    params.permit(:status)
  end

  def status_params
    params.require(:hashcat_status).
      permit(:original_line, :time, :session,
             :status, :target, :time_start, :rejected, :restore_point,
             :format, :hashcat_status,
             :estimated_stop,
             guess: [ :guess_base, :guess_base_count, :guess_base_offset, :guess_base_percent,
                     :guess_mod, :guess_mod_count, :guess_mod_offset, :guess_mod_percent,
                     :guess_base_percent, :guess_mode ],
             devices: [ :device_id, :device_name, :device_type, :speed, :util, :temp ],
             progress: [], recovered_hashes: [], recovered_salts: [],
             task: {}
      )
  end
end
