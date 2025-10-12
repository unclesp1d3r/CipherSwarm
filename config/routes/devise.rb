# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

devise_for :users, skip: [:registrations]
as :user do
  get "users/edit" => "devise/registrations#edit", :as => "edit_user_registration"
  put "users" => "devise/registrations#update", :as => "user_registration"
end
