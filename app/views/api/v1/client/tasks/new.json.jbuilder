# frozen_string_literal: true

json.partial! "api/v1/client/tasks/task", task: @task unless @task.nil?
