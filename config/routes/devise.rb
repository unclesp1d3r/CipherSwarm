# frozen_string_literal: true

devise_for :users, skip: [:registrations]
as :user do
  get "users/edit" => "devise/registrations#edit", :as => "edit_user_registration"
  put "users" => "devise/registrations#update", :as => "user_registration"
  post "toggle_hide_completed_activities" => "home#toggle_hide_completed_activities"
end
