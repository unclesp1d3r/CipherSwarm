# frozen_string_literal: true

namespace :admin do
  resources :agents
  resources :attacks
  resources :campaigns
  resources :cracker_binaries
  resources :hash_items
  resources :hash_lists
  resources :operating_systems
  resources :projects
  resources :project_users
  resources :rule_lists
  resources :tasks
  resources :users
  resources :word_lists
  root to: "agents#index"
end
