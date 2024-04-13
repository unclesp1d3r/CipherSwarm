# frozen_string_literal: true

json.extract! task, :id, :attack_id, :agent_id, :start_date, :created_at, :updated_at
json.url task_url(task, format: :json)
