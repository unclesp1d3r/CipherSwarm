# == Route Map
#
#                                   Prefix Verb   URI Pattern                                                                                       Controller#Action
#                                   agents GET    /agents(.:format)                                                                                 agents#index
#                                          POST   /agents(.:format)                                                                                 agents#create
#                                new_agent GET    /agents/new(.:format)                                                                             agents#new
#                               edit_agent GET    /agents/:id/edit(.:format)                                                                        agents#edit
#                                    agent GET    /agents/:id(.:format)                                                                             agents#show
#                                          PATCH  /agents/:id(.:format)                                                                             agents#update
#                                          PUT    /agents/:id(.:format)                                                                             agents#update
#                                          DELETE /agents/:id(.:format)                                                                             agents#destroy
#                                 projects POST   /projects(.:format)                                                                               projects#create
#                              new_project GET    /projects/new(.:format)                                                                           projects#new
#                             edit_project GET    /projects/:id/edit(.:format)                                                                      projects#edit
#                                  project GET    /projects/:id(.:format)                                                                           projects#show
#                                          PATCH  /projects/:id(.:format)                                                                           projects#update
#                                          PUT    /projects/:id(.:format)                                                                           projects#update
#                                          DELETE /projects/:id(.:format)                                                                           projects#destroy
#                              admin_index GET    /admin/index(.:format)                                                                            admin#index
#                              unlock_user POST   /admin/unlock_user/:id(.:format)                                                                  admin#unlock_user
#                                lock_user POST   /admin/lock_user/:id(.:format)                                                                    admin#lock_user
#                              bad_request        /bad-request(.:format)                                                                            errors#bad_request
#                           not_authorized        /not_authorized(.:format)                                                                         errors#not_authorized
#                          route_not_found        /route-not-found(.:format)                                                                        errors#route_not_found
#                       resource_not_found        /resource-not-found(.:format)                                                                     errors#resource_not_found
#                         missing_template        /missing-template(.:format)                                                                       errors#missing_template
#                           not_acceptable        /not-acceptable(.:format)                                                                         errors#not_acceptable
#                            unknown_error        /unknown-error(.:format)                                                                          errors#unknown_error
#                      service_unavailable        /service-unavailable(.:format)                                                                    errors#service_unavailable
#                                                 /400(.:format)                                                                                    errors#bad_request
#                                                 /401(.:format)                                                                                    errors#not_authorized
#                                                 /403(.:format)                                                                                    errors#not_authorized
#                                                 /404(.:format)                                                                                    errors#resource_not_found
#                                                 /406(.:format)                                                                                    errors#not_acceptable
#                                                 /422(.:format)                                                                                    errors#not_acceptable
#                                                 /500(.:format)                                                                                    errors#unknown_error
#                         new_user_session GET    /users/sign_in(.:format)                                                                          devise/sessions#new
#                             user_session POST   /users/sign_in(.:format)                                                                          devise/sessions#create
#                     destroy_user_session DELETE /users/sign_out(.:format)                                                                         devise/sessions#destroy
#                        new_user_password GET    /users/password/new(.:format)                                                                     devise/passwords#new
#                       edit_user_password GET    /users/password/edit(.:format)                                                                    devise/passwords#edit
#                            user_password PATCH  /users/password(.:format)                                                                         devise/passwords#update
#                                          PUT    /users/password(.:format)                                                                         devise/passwords#update
#                                          POST   /users/password(.:format)                                                                         devise/passwords#create
#                       rails_health_check GET    /up(.:format)                                                                                     rails/health#show
#                       authenticated_root GET    /                                                                                                 home#index
#                                     root GET    /                                                                                                 redirect(301, /users/sign_in)
#         turbo_recede_historical_location GET    /recede_historical_location(.:format)                                                             turbo/native/navigation#recede
#         turbo_resume_historical_location GET    /resume_historical_location(.:format)                                                             turbo/native/navigation#resume
#        turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                                                            turbo/native/navigation#refresh
#            rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format)                                           action_mailbox/ingresses/postmark/inbound_emails#create
#               rails_relay_inbound_emails POST   /rails/action_mailbox/relay/inbound_emails(.:format)                                              action_mailbox/ingresses/relay/inbound_emails#create
#            rails_sendgrid_inbound_emails POST   /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
#      rails_mandrill_inbound_health_check GET    /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
#            rails_mandrill_inbound_emails POST   /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#create
#             rails_mailgun_inbound_emails POST   /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                       action_mailbox/ingresses/mailgun/inbound_emails#create
#           rails_conductor_inbound_emails GET    /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#index
#                                          POST   /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#create
#        new_rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                      rails/conductor/action_mailbox/inbound_emails#new
#            rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                      rails/conductor/action_mailbox/inbound_emails#show
# new_rails_conductor_inbound_email_source GET    /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#new
#    rails_conductor_inbound_email_sources POST   /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                  rails/conductor/action_mailbox/inbound_emails/sources#create
#    rails_conductor_inbound_email_reroute POST   /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                               rails/conductor/action_mailbox/reroutes#create
# rails_conductor_inbound_email_incinerate POST   /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                            rails/conductor/action_mailbox/incinerates#create
#                       rails_service_blob GET    /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                 rails_service_blob_proxy GET    /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                          GET    /rails/active_storage/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                rails_blob_representation GET    /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#          rails_blob_representation_proxy GET    /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                          GET    /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                       rails_disk_service GET    /rails/active_storage/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                update_rails_disk_service PUT    /rails/active_storage/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                     rails_direct_uploads POST   /rails/active_storage/direct_uploads(.:format)                                                    active_storage/direct_uploads#create

Rails.application.routes.draw do
  resources :agents
  resources :projects, only: %i[ show new create edit update destroy ]

  # Define the admin routes
  get "admin/index"
  post "admin/unlock_user/:id", to: "admin#unlock_user", as: "unlock_user"
  post "admin/lock_user/:id", to: "admin#lock_user", as: "lock_user"

  # Define the error routes
  match "bad-request", to: "errors#bad_request", as: "bad_request", via: :all
  match "not_authorized", to: "errors#not_authorized", as: "not_authorized", via: :all
  match "route-not-found", to: "errors#route_not_found", as: "route_not_found", via: :all
  match "resource-not-found", to: "errors#resource_not_found", as: "resource_not_found", via: :all
  match "missing-template", to: "errors#missing_template", as: "missing_template", via: :all
  match "not-acceptable", to: "errors#not_acceptable", as: "not_acceptable", via: :all
  match "unknown-error", to: "errors#unknown_error", as: "unknown_error", via: :all
  match "service-unavailable", to: "errors#service_unavailable", as: "service_unavailable", via: :all

  match "/400", to: "errors#bad_request", via: :all
  match "/401", to: "errors#not_authorized", via: :all
  match "/403", to: "errors#not_authorized", via: :all
  match "/404", to: "errors#resource_not_found", via: :all
  match "/406", to: "errors#not_acceptable", via: :all
  match "/422", to: "errors#not_acceptable", via: :all
  match "/500", to: "errors#unknown_error", via: :all

  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  authenticated :user do
    root to: "home#index", as: :authenticated_root
  end

  root to: redirect("/users/sign_in")
end
