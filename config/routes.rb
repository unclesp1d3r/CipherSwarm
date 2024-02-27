Rails.application.routes.draw do
  get 'admin/index'
  match "bad-request", to: "errors#bad_request", as: "bad_request", via: :all
  match "not_authorized", to: "errors#not_authorized", as: "not_authorized", via: :all
  match "route-not-found", to: "errors#route_not_found", as: "route_not_found", via: :all
  match "resource-not-found", to: "errors#resource_not_found", as: "resource_not_found", via: :all
  match "missing-template", to: "errors#missing_template", as: "missing_template", via: :all
  match "not-acceptable", to: "errors#not_acceptable", as: "not_acceptable", via: :all
  match "unknown-error", to: "errors#unknown_error", as: "unknown_error", via: :all
  match "service-unavailable", to: "errors#service_unavailable", as: "service_unavailable", via: :all

  match '/400', to: 'errors#bad_request', via: :all
  match '/401', to: 'errors#not_authorized', via: :all
  match '/403', to: 'errors#not_authorized', via: :all
  match '/404', to: 'errors#resource_not_found', via: :all
  match '/406', to: 'errors#not_acceptable', via: :all
  match '/422', to: 'errors#not_acceptable', via: :all
  match '/500', to: 'errors#unknown_error', via: :all

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#index"

end
