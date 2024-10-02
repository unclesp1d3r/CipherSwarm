# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# This file defines the routes for the client namespace in the CipherSwarm application.
# It includes routes for various resources such as crackers, configuration, authentication,
# agents, attacks, and tasks. Each route is mapped to a specific controller action.
#
# Routes:
# - GET    /client/crackers/check_for_cracker_update -> crackers#check_for_cracker_update
# - GET    /client/configuration                     -> configuration#index
# - GET    /client/authenticate                      -> authenticate#index
# - GET    /client/attacks/:id/hash_list             -> attacks#hash_list
# - GET    /client/tasks/:id/get_zaps                -> tasks#get_zaps
# - POST   /client/agents/:id/heartbeat              -> agents#heartbeat
# - POST   /client/agents/:id/submit_benchmark       -> agents#submit_benchmark
# - POST   /client/agents/:id/submit_error           -> agents#submit_error
# - POST   /client/agents/:id/shutdown               -> agents#shutdown
# - POST   /client/tasks/:id/submit_crack            -> tasks#submit_crack
# - POST   /client/tasks/:id/submit_status           -> tasks#submit_status
# - POST   /client/tasks/:id/accept_task             -> tasks#accept_task
# - POST   /client/tasks/:id/exhausted               -> tasks#exhausted
# - POST   /client/tasks/:id/abandon                 -> tasks#abandon
#
# Resources:
# - agents: only allows show and update actions
# - attacks: only allows show action
# - tasks: only allows show, new, and update actions
namespace :client do
  get "crackers/check_for_cracker_update", to: "crackers#check_for_cracker_update"
  get "configuration"
  get "authenticate"
  resources :agents, only: %i[ show update ]
  post "agents/:id/heartbeat", to: "agents#heartbeat", as: "agents_heartbeat"
  post "agents/:id/submit_benchmark", to: "agents#submit_benchmark", as: "agents_submit_benchmark"
  post "agents/:id/submit_error", to: "agents#submit_error", as: "agents_submit_error"
  post "agents/:id/shutdown", to: "agents#shutdown", as: "agents_shutdown"
  resources :attacks, only: %i[ show ]
  get "attacks/:id/hash_list", to: "attacks#hash_list", as: "attack_hash_list"
  resources :tasks, only: %i[ show new update ]
  post "tasks/:id/submit_crack", to: "tasks#submit_crack", as: "task_submit_crack"
  post "tasks/:id/submit_status", to: "tasks#submit_status", as: "task_submit_status"
  post "tasks/:id/accept_task", to: "tasks#accept_task", as: "task_accept_task"
  post "tasks/:id/exhausted", to: "tasks#exhausted", as: "task_exhausted"
  post "tasks/:id/abandon", to: "tasks#abandon", as: "task_abandon"
  get "tasks/:id/get_zaps", to: "tasks#get_zaps", as: "task_get_zaps"
end
