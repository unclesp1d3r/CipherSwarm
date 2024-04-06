# frozen_string_literal: true

namespace :client do
  get "crackers/check_for_cracker_update", to: "crackers#check_for_cracker_update"
  get "configuration"
  get "authenticate"
  resources :agents, only: %i[ show update ]
  post "agents/:id/heartbeat", to: "agents#heartbeat", as: "agents_heartbeat"
  get "agents/:id/last_benchmark", to: "agents#last_benchmark", as: "agents_last_benchmark"
  post "agents/:id/submit_benchmark", to: "agents#submit_benchmark", as: "agents_submit_benchmark"
  resources :attacks, only: %i[ show ]
  get "attacks/:id/hash_list", to: "attacks#hash_list", as: "attack_hash_list"
  resources :tasks, only: %i[ show new update]
  post "tasks/:id/submit_crack", to: "tasks#submit_crack", as: "task_submit_crack"
  post "tasks/:id/submit_status", to: "tasks#submit_status", as: "task_submit_status"
  post "tasks/:id/accept_task", to: "tasks#accept_task", as: "task_accept_task"
  post "tasks/:id/exhausted", to: "tasks#exhausted", as: "task_exhausted"
end
