class Api::V1::Client::TasksController < Api::V1::BaseController # rubocop:disable Metrics/ClassLength
  resource_description do
    short "Client tasks"
    description "Tasks to be executed by the client"
    formats [ "json" ]
    header "Authorization", "The token to authenticate the agent with.", required: true
  end

  def_param_group :task do
    property :id, Integer, desc: "The unique identifier of the task."
    property :attack_id, Integer, desc: "The unique identifier of the attack."
    property :start_date, DateTime, desc: "The date and time when the task was started."
    param :status, Task.statuses.keys, desc: "The status of the task."
  end

  api! "List all tasks for the current agent"
  param :id, :number, desc: "The unique identifier of the task."
  returns code: 200, desc: "Task was successfully retrieved." do
    param_group :task
  end
  returns code: :not_found, desc: "Requested task was not found."
  error :not_found, "The task was not found."
  error 401, "The agent is not authorized to view the task."

  def show
    @task = @agent.tasks.includes(:attack).find(params[:id])
  end

  api! "Get a new task for the current agent"
  returns code: 200, desc: "A new task was successfully retrieved." do
    param_group :task
  end
  returns code: :no_content, desc: "No tasks are available."
  error 401, "The agent is not authorized to obtain a new task."

  def new
    @task = @agent.new_task
    if @task.nil?
      render status: :no_content
    end
  end

  api! "Update the status of a task"
  param :id, :number, desc: "The unique identifier of the task."
  param_group :task, required: true
  returns code: 200, desc: "Task was successfully updated." do
    param_group :task
  end
  returns code: :unprocessable_entity, desc: "Task could not be updated." do
    param :errors, Hash, desc: "The errors that occurred while updating the task."
  end

  def update
    @task = @agent.tasks.find(params[:id])
    if @task.update(task_params)
      render json: @task
    else
      render json: @task.errors, status: :unprocessable_entity
    end
  end

  api! "Submit a cracked hash for a task"
  param :id, :number, desc: "The unique identifier of the task."
  param :timestamp, String, required: true, desc: "The timestamp of when the hash was cracked."
  param :hash, String, required: true, desc: "The hash that was cracked."
  param :plaintext, String, required: true, desc: "The plain text value of the cracked hash."
  returns code: 200, desc: "The hash was successfully submitted."
  returns code: 204, desc: "All hash items are successfully cracked and the hash list is completed."
  returns code: :not_found, desc: "The hash was not found."
  error :not_found, "The task was not found."
  error 401, "The agent is not authorized to submit a cracked hash."

  def submit_crack
    timestamp = params[:timestamp]
    hash = params[:hash]
    plain_text = params[:plaintext]
    task = @agent.tasks.find(params[:id])
    hash_list = task.hash_list
    hash_item = hash_list.hash_items.where(hash_value: hash)
    if hash_item.nil?
      render status: :no_content
    else
      if hash_list.uncracked_items.empty?
        render status: :no_content
        task.update_status
        return
      end

      unless hash_item.update(plain_text: plain_text, cracked: true, cracked_time: timestamp)
        render json: { message: "Error updating hash" }, status: :unprocessable_entity
      end
      task.update(activity_timestamp: Time.zone.now)
      task.update_status
    end
  end

  api! "Accept a task"
  param :id, :number, desc: "The unique identifier of the task."
  returns code: 200, desc: "The task was successfully accepted."
  returns code: :not_found, desc: "The task was not found."
  returns code: :unprocessable_entity, desc: "The task could not be accepted."
  returns code: 204, desc: "The task is already completed."
  error :not_found, "The task was not found."
  error 401, "The agent is not authorized to accept the task."

  def accept_task
    @task = @agent.tasks.find(params[:id])
    if @task.completed?
      render json: { message: "Task already completed" }, status: :unprocessable_entity
      return
    end

    if !@task.update(status: :running, start_date: Time.zone.now, activity_timestamp: Time.zone.now)
      render json: @task.errors, status: :unprocessable_entity
    else
      @task.update_status
    end
  end

  api! "Submit the status of a task"

  def submit_status
    @task = @agent.tasks.find(params[:id])
    @task.update(activity_timestamp: Time.zone.now)
    @task.update_status
  end

  api! "Mark a task as exhausted"
  param :id, :number, desc: "The unique identifier of the task."
  returns code: 200, desc: "The task was successfully marked as exhausted."
  returns code: :not_found, desc: "The task was not found."
  error :not_found, "The task was not found."
  error 401, "The agent is not authorized to mark the task as exhausted."

  def exhausted
    @task = @agent.tasks.find(params[:id])
    if @task.update(status: :exhausted)
      @task.update_status
    end
  end

  private

  def task_params
    params.permit(:status)
  end
end
