# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# This configuration file defines the routes for the admin namespace in the CipherSwarm application.
# It includes RESTful routes for various resources such as agents, attacks, campaigns, and more.
# The root path for the admin namespace is set to the index action of the agents controller.
namespace :admin do
  resources :agents
  resources :attacks
  resources :campaigns
  resources :cracker_binaries
  resources :hash_items
  resources :hash_lists
  resources :mask_lists
  resources :operating_systems
  resources :projects
  resources :project_users
  resources :rule_lists
  resources :tasks
  resources :users
  resources :word_lists
  root to: "agents#index"
end
