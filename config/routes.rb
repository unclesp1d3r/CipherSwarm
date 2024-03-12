# == Route Map
#
#                                          Prefix Verb   URI Pattern                                                                                       Controller#Action
#                                    admin_agents GET    /admin/agents(.:format)                                                                           admin/agents#index
#                                                 POST   /admin/agents(.:format)                                                                           admin/agents#create
#                                 new_admin_agent GET    /admin/agents/new(.:format)                                                                       admin/agents#new
#                                edit_admin_agent GET    /admin/agents/:id/edit(.:format)                                                                  admin/agents#edit
#                                     admin_agent GET    /admin/agents/:id(.:format)                                                                       admin/agents#show
#                                                 PATCH  /admin/agents/:id(.:format)                                                                       admin/agents#update
#                                                 PUT    /admin/agents/:id(.:format)                                                                       admin/agents#update
#                                                 DELETE /admin/agents/:id(.:format)                                                                       admin/agents#destroy
#                                  admin_crackers GET    /admin/crackers(.:format)                                                                         admin/crackers#index
#                                                 POST   /admin/crackers(.:format)                                                                         admin/crackers#create
#                               new_admin_cracker GET    /admin/crackers/new(.:format)                                                                     admin/crackers#new
#                              edit_admin_cracker GET    /admin/crackers/:id/edit(.:format)                                                                admin/crackers#edit
#                                   admin_cracker GET    /admin/crackers/:id(.:format)                                                                     admin/crackers#show
#                                                 PATCH  /admin/crackers/:id(.:format)                                                                     admin/crackers#update
#                                                 PUT    /admin/crackers/:id(.:format)                                                                     admin/crackers#update
#                                                 DELETE /admin/crackers/:id(.:format)                                                                     admin/crackers#destroy
#                          admin_cracker_binaries GET    /admin/cracker_binaries(.:format)                                                                 admin/cracker_binaries#index
#                                                 POST   /admin/cracker_binaries(.:format)                                                                 admin/cracker_binaries#create
#                        new_admin_cracker_binary GET    /admin/cracker_binaries/new(.:format)                                                             admin/cracker_binaries#new
#                       edit_admin_cracker_binary GET    /admin/cracker_binaries/:id/edit(.:format)                                                        admin/cracker_binaries#edit
#                            admin_cracker_binary GET    /admin/cracker_binaries/:id(.:format)                                                             admin/cracker_binaries#show
#                                                 PATCH  /admin/cracker_binaries/:id(.:format)                                                             admin/cracker_binaries#update
#                                                 PUT    /admin/cracker_binaries/:id(.:format)                                                             admin/cracker_binaries#update
#                                                 DELETE /admin/cracker_binaries/:id(.:format)                                                             admin/cracker_binaries#destroy
#                                admin_hash_items GET    /admin/hash_items(.:format)                                                                       admin/hash_items#index
#                                                 POST   /admin/hash_items(.:format)                                                                       admin/hash_items#create
#                             new_admin_hash_item GET    /admin/hash_items/new(.:format)                                                                   admin/hash_items#new
#                            edit_admin_hash_item GET    /admin/hash_items/:id/edit(.:format)                                                              admin/hash_items#edit
#                                 admin_hash_item GET    /admin/hash_items/:id(.:format)                                                                   admin/hash_items#show
#                                                 PATCH  /admin/hash_items/:id(.:format)                                                                   admin/hash_items#update
#                                                 PUT    /admin/hash_items/:id(.:format)                                                                   admin/hash_items#update
#                                                 DELETE /admin/hash_items/:id(.:format)                                                                   admin/hash_items#destroy
#                                admin_hash_lists GET    /admin/hash_lists(.:format)                                                                       admin/hash_lists#index
#                                                 POST   /admin/hash_lists(.:format)                                                                       admin/hash_lists#create
#                             new_admin_hash_list GET    /admin/hash_lists/new(.:format)                                                                   admin/hash_lists#new
#                            edit_admin_hash_list GET    /admin/hash_lists/:id/edit(.:format)                                                              admin/hash_lists#edit
#                                 admin_hash_list GET    /admin/hash_lists/:id(.:format)                                                                   admin/hash_lists#show
#                                                 PATCH  /admin/hash_lists/:id(.:format)                                                                   admin/hash_lists#update
#                                                 PUT    /admin/hash_lists/:id(.:format)                                                                   admin/hash_lists#update
#                                                 DELETE /admin/hash_lists/:id(.:format)                                                                   admin/hash_lists#destroy
#                         admin_operating_systems GET    /admin/operating_systems(.:format)                                                                admin/operating_systems#index
#                                                 POST   /admin/operating_systems(.:format)                                                                admin/operating_systems#create
#                      new_admin_operating_system GET    /admin/operating_systems/new(.:format)                                                            admin/operating_systems#new
#                     edit_admin_operating_system GET    /admin/operating_systems/:id/edit(.:format)                                                       admin/operating_systems#edit
#                          admin_operating_system GET    /admin/operating_systems/:id(.:format)                                                            admin/operating_systems#show
#                                                 PATCH  /admin/operating_systems/:id(.:format)                                                            admin/operating_systems#update
#                                                 PUT    /admin/operating_systems/:id(.:format)                                                            admin/operating_systems#update
#                                                 DELETE /admin/operating_systems/:id(.:format)                                                            admin/operating_systems#destroy
#                                  admin_projects GET    /admin/projects(.:format)                                                                         admin/projects#index
#                                                 POST   /admin/projects(.:format)                                                                         admin/projects#create
#                               new_admin_project GET    /admin/projects/new(.:format)                                                                     admin/projects#new
#                              edit_admin_project GET    /admin/projects/:id/edit(.:format)                                                                admin/projects#edit
#                                   admin_project GET    /admin/projects/:id(.:format)                                                                     admin/projects#show
#                                                 PATCH  /admin/projects/:id(.:format)                                                                     admin/projects#update
#                                                 PUT    /admin/projects/:id(.:format)                                                                     admin/projects#update
#                                                 DELETE /admin/projects/:id(.:format)                                                                     admin/projects#destroy
#                             admin_project_users GET    /admin/project_users(.:format)                                                                    admin/project_users#index
#                                                 POST   /admin/project_users(.:format)                                                                    admin/project_users#create
#                          new_admin_project_user GET    /admin/project_users/new(.:format)                                                                admin/project_users#new
#                         edit_admin_project_user GET    /admin/project_users/:id/edit(.:format)                                                           admin/project_users#edit
#                              admin_project_user GET    /admin/project_users/:id(.:format)                                                                admin/project_users#show
#                                                 PATCH  /admin/project_users/:id(.:format)                                                                admin/project_users#update
#                                                 PUT    /admin/project_users/:id(.:format)                                                                admin/project_users#update
#                                                 DELETE /admin/project_users/:id(.:format)                                                                admin/project_users#destroy
#                                admin_rule_lists GET    /admin/rule_lists(.:format)                                                                       admin/rule_lists#index
#                                                 POST   /admin/rule_lists(.:format)                                                                       admin/rule_lists#create
#                             new_admin_rule_list GET    /admin/rule_lists/new(.:format)                                                                   admin/rule_lists#new
#                            edit_admin_rule_list GET    /admin/rule_lists/:id/edit(.:format)                                                              admin/rule_lists#edit
#                                 admin_rule_list GET    /admin/rule_lists/:id(.:format)                                                                   admin/rule_lists#show
#                                                 PATCH  /admin/rule_lists/:id(.:format)                                                                   admin/rule_lists#update
#                                                 PUT    /admin/rule_lists/:id(.:format)                                                                   admin/rule_lists#update
#                                                 DELETE /admin/rule_lists/:id(.:format)                                                                   admin/rule_lists#destroy
#                                     admin_users GET    /admin/users(.:format)                                                                            admin/users#index
#                                                 POST   /admin/users(.:format)                                                                            admin/users#create
#                                  new_admin_user GET    /admin/users/new(.:format)                                                                        admin/users#new
#                                 edit_admin_user GET    /admin/users/:id/edit(.:format)                                                                   admin/users#edit
#                                      admin_user GET    /admin/users/:id(.:format)                                                                        admin/users#show
#                                                 PATCH  /admin/users/:id(.:format)                                                                        admin/users#update
#                                                 PUT    /admin/users/:id(.:format)                                                                        admin/users#update
#                                                 DELETE /admin/users/:id(.:format)                                                                        admin/users#destroy
#                                admin_word_lists GET    /admin/word_lists(.:format)                                                                       admin/word_lists#index
#                                                 POST   /admin/word_lists(.:format)                                                                       admin/word_lists#create
#                             new_admin_word_list GET    /admin/word_lists/new(.:format)                                                                   admin/word_lists#new
#                            edit_admin_word_list GET    /admin/word_lists/:id/edit(.:format)                                                              admin/word_lists#edit
#                                 admin_word_list GET    /admin/word_lists/:id(.:format)                                                                   admin/word_lists#show
#                                                 PATCH  /admin/word_lists/:id(.:format)                                                                   admin/word_lists#update
#                                                 PUT    /admin/word_lists/:id(.:format)                                                                   admin/word_lists#update
#                                                 DELETE /admin/word_lists/:id(.:format)                                                                   admin/word_lists#destroy
#                                      admin_root GET    /admin(.:format)                                                                                  admin/agents#index
#                                      hash_lists GET    /hash_lists(.:format)                                                                             hash_lists#index
#                                                 POST   /hash_lists(.:format)                                                                             hash_lists#create
#                                   new_hash_list GET    /hash_lists/new(.:format)                                                                         hash_lists#new
#                                  edit_hash_list GET    /hash_lists/:id/edit(.:format)                                                                    hash_lists#edit
#                                       hash_list GET    /hash_lists/:id(.:format)                                                                         hash_lists#show
#                                                 PATCH  /hash_lists/:id(.:format)                                                                         hash_lists#update
#                                                 PUT    /hash_lists/:id(.:format)                                                                         hash_lists#update
#                                                 DELETE /hash_lists/:id(.:format)                                                                         hash_lists#destroy
#                                      rule_lists GET    /rule_lists(.:format)                                                                             rule_lists#index
#                                                 POST   /rule_lists(.:format)                                                                             rule_lists#create
#                                   new_rule_list GET    /rule_lists/new(.:format)                                                                         rule_lists#new
#                                  edit_rule_list GET    /rule_lists/:id/edit(.:format)                                                                    rule_lists#edit
#                                       rule_list GET    /rule_lists/:id(.:format)                                                                         rule_lists#show
#                                                 PATCH  /rule_lists/:id(.:format)                                                                         rule_lists#update
#                                                 PUT    /rule_lists/:id(.:format)                                                                         rule_lists#update
#                                                 DELETE /rule_lists/:id(.:format)                                                                         rule_lists#destroy
#                                      word_lists GET    /word_lists(.:format)                                                                             word_lists#index
#                                                 POST   /word_lists(.:format)                                                                             word_lists#create
#                                   new_word_list GET    /word_lists/new(.:format)                                                                         word_lists#new
#                                  edit_word_list GET    /word_lists/:id/edit(.:format)                                                                    word_lists#edit
#                                       word_list GET    /word_lists/:id(.:format)                                                                         word_lists#show
#                                                 PATCH  /word_lists/:id(.:format)                                                                         word_lists#update
#                                                 PUT    /word_lists/:id(.:format)                                                                         word_lists#update
#                                                 DELETE /word_lists/:id(.:format)                                                                         word_lists#destroy
#                        cracker_cracker_binaries GET    /crackers/:cracker_id/cracker_binaries(.:format)                                                  cracker_binaries#index
#                                                 POST   /crackers/:cracker_id/cracker_binaries(.:format)                                                  cracker_binaries#create
#                      new_cracker_cracker_binary GET    /crackers/:cracker_id/cracker_binaries/new(.:format)                                              cracker_binaries#new
#                     edit_cracker_cracker_binary GET    /crackers/:cracker_id/cracker_binaries/:id/edit(.:format)                                         cracker_binaries#edit
#                          cracker_cracker_binary GET    /crackers/:cracker_id/cracker_binaries/:id(.:format)                                              cracker_binaries#show
#                                                 PATCH  /crackers/:cracker_id/cracker_binaries/:id(.:format)                                              cracker_binaries#update
#                                                 PUT    /crackers/:cracker_id/cracker_binaries/:id(.:format)                                              cracker_binaries#update
#                                                 DELETE /crackers/:cracker_id/cracker_binaries/:id(.:format)                                              cracker_binaries#destroy
#                                        crackers GET    /crackers(.:format)                                                                               crackers#index
#                                                 POST   /crackers(.:format)                                                                               crackers#create
#                                     new_cracker GET    /crackers/new(.:format)                                                                           crackers#new
#                                    edit_cracker GET    /crackers/:id/edit(.:format)                                                                      crackers#edit
#                                         cracker GET    /crackers/:id(.:format)                                                                           crackers#show
#                                                 PATCH  /crackers/:id(.:format)                                                                           crackers#update
#                                                 PUT    /crackers/:id(.:format)                                                                           crackers#update
#                                                 DELETE /crackers/:id(.:format)                                                                           crackers#destroy
# api_v1_client_crackers_check_for_cracker_update GET    /api/v1/client/crackers/check_for_cracker_update(.:format)                                        api/v1/client/crackers#check_for_cracker_update {:format=>:json}
#                     api_v1_client_configuration GET    /api/v1/client/configuration(.:format)                                                            api/v1/client#configuration {:format=>:json}
#                      api_v1_client_authenticate GET    /api/v1/client/authenticate(.:format)                                                             api/v1/client#authenticate {:format=>:json}
#                             api_v1_client_agent GET    /api/v1/client/agents/:id(.:format)                                                               api/v1/client/agents#show {:format=>:json}
#                                                 PATCH  /api/v1/client/agents/:id(.:format)                                                               api/v1/client/agents#update {:format=>:json}
#                                                 PUT    /api/v1/client/agents/:id(.:format)                                                               api/v1/client/agents#update {:format=>:json}
#                          api_v1_client_crackers GET    /api/v1/client/crackers(.:format)                                                                 api/v1/client/crackers#index {:format=>:json}
#                           api_v1_client_cracker GET    /api/v1/client/crackers/:id(.:format)                                                             api/v1/client/crackers#show {:format=>:json}
#                                          agents GET    /agents(.:format)                                                                                 agents#index
#                                                 POST   /agents(.:format)                                                                                 agents#create
#                                       new_agent GET    /agents/new(.:format)                                                                             agents#new
#                                      edit_agent GET    /agents/:id/edit(.:format)                                                                        agents#edit
#                                           agent GET    /agents/:id(.:format)                                                                             agents#show
#                                                 PATCH  /agents/:id(.:format)                                                                             agents#update
#                                                 PUT    /agents/:id(.:format)                                                                             agents#update
#                                                 DELETE /agents/:id(.:format)                                                                             agents#destroy
#                                        projects POST   /projects(.:format)                                                                               projects#create
#                                     new_project GET    /projects/new(.:format)                                                                           projects#new
#                                    edit_project GET    /projects/:id/edit(.:format)                                                                      projects#edit
#                                         project GET    /projects/:id(.:format)                                                                           projects#show
#                                                 PATCH  /projects/:id(.:format)                                                                           projects#update
#                                                 PUT    /projects/:id(.:format)                                                                           projects#update
#                                                 DELETE /projects/:id(.:format)                                                                           projects#destroy
#                                     admin_index GET    /admin/index(.:format)                                                                            admin#index
#                                     unlock_user POST   /admin/unlock_user/:id(.:format)                                                                  admin#unlock_user
#                                       lock_user POST   /admin/lock_user/:id(.:format)                                                                    admin#lock_user
#                                     create_user POST   /admin/create_user(.:format)                                                                      admin#create_user
#                                        new_user GET    /admin/new_user(.:format)                                                                         admin#new_user
#                                     bad_request        /bad-request(.:format)                                                                            errors#bad_request
#                                  not_authorized        /not_authorized(.:format)                                                                         errors#not_authorized
#                                 route_not_found        /route-not-found(.:format)                                                                        errors#route_not_found
#                              resource_not_found        /resource-not-found(.:format)                                                                     errors#resource_not_found
#                                missing_template        /missing-template(.:format)                                                                       errors#missing_template
#                                  not_acceptable        /not-acceptable(.:format)                                                                         errors#not_acceptable
#                                   unknown_error        /unknown-error(.:format)                                                                          errors#unknown_error
#                             service_unavailable        /service-unavailable(.:format)                                                                    errors#service_unavailable
#                                                        /400(.:format)                                                                                    errors#bad_request
#                                                        /401(.:format)                                                                                    errors#not_authorized
#                                                        /403(.:format)                                                                                    errors#not_authorized
#                                                        /404(.:format)                                                                                    errors#resource_not_found
#                                                        /406(.:format)                                                                                    errors#not_acceptable
#                                                        /422(.:format)                                                                                    errors#not_acceptable
#                                                        /500(.:format)                                                                                    errors#unknown_error
#                                new_user_session GET    /users/sign_in(.:format)                                                                          devise/sessions#new
#                                    user_session POST   /users/sign_in(.:format)                                                                          devise/sessions#create
#                            destroy_user_session DELETE /users/sign_out(.:format)                                                                         devise/sessions#destroy
#                               new_user_password GET    /users/password/new(.:format)                                                                     devise/passwords#new
#                              edit_user_password GET    /users/password/edit(.:format)                                                                    devise/passwords#edit
#                                   user_password PATCH  /users/password(.:format)                                                                         devise/passwords#update
#                                                 PUT    /users/password(.:format)                                                                         devise/passwords#update
#                                                 POST   /users/password(.:format)                                                                         devise/passwords#create
#                              rails_health_check GET    /up(.:format)                                                                                     rails/health#show
#                              authenticated_root GET    /                                                                                                 home#index
#                                            root GET    /                                                                                                 redirect(301, /users/sign_in)
#                turbo_recede_historical_location GET    /recede_historical_location(.:format)                                                             turbo/native/navigation#recede
#                turbo_resume_historical_location GET    /resume_historical_location(.:format)                                                             turbo/native/navigation#resume
#               turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                                                            turbo/native/navigation#refresh
#                   rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format)                                           action_mailbox/ingresses/postmark/inbound_emails#create
#                      rails_relay_inbound_emails POST   /rails/action_mailbox/relay/inbound_emails(.:format)                                              action_mailbox/ingresses/relay/inbound_emails#create
#                   rails_sendgrid_inbound_emails POST   /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
#             rails_mandrill_inbound_health_check GET    /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
#                   rails_mandrill_inbound_emails POST   /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#create
#                    rails_mailgun_inbound_emails POST   /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                       action_mailbox/ingresses/mailgun/inbound_emails#create
#                  rails_conductor_inbound_emails GET    /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#index
#                                                 POST   /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#create
#               new_rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                      rails/conductor/action_mailbox/inbound_emails#new
#                   rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                      rails/conductor/action_mailbox/inbound_emails#show
#        new_rails_conductor_inbound_email_source GET    /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#new
#           rails_conductor_inbound_email_sources POST   /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                  rails/conductor/action_mailbox/inbound_emails/sources#create
#           rails_conductor_inbound_email_reroute POST   /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                               rails/conductor/action_mailbox/reroutes#create
#        rails_conductor_inbound_email_incinerate POST   /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                            rails/conductor/action_mailbox/incinerates#create
#                              rails_service_blob GET    /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                        rails_service_blob_proxy GET    /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                                 GET    /rails/active_storage/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                       rails_blob_representation GET    /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#                 rails_blob_representation_proxy GET    /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                                 GET    /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                              rails_disk_service GET    /rails/active_storage/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                       update_rails_disk_service PUT    /rails/active_storage/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                            rails_direct_uploads POST   /rails/active_storage/direct_uploads(.:format)                                                    active_storage/direct_uploads#create

Rails.application.routes.draw do
  namespace :admin do
    resources :agents
    resources :crackers
    resources :cracker_binaries
    resources :hash_items
    resources :hash_lists
    resources :operating_systems
    resources :projects
    resources :project_users
    resources :rule_lists
    resources :users
    resources :word_lists

    root to: "agents#index"
  end
  resources :hash_lists
  resources :rule_lists
  resources :word_lists
  resources :crackers do
    resources :cracker_binaries
  end
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      namespace :client do
        get "crackers/check_for_cracker_update", to: "crackers#check_for_cracker_update"
        get "configuration"
        get "authenticate"
        resources :agents, only: %i[ show update ]
        resources :crackers, only: %i[ index show ]
      end
    end
  end

  resources :agents
  resources :projects, only: %i[ show new create edit update destroy ]

  # Define the admin routes
  get "admin/index"
  post "admin/unlock_user/:id", to: "admin#unlock_user", as: "unlock_user"
  post "admin/lock_user/:id", to: "admin#lock_user", as: "lock_user"
  post "admin/create_user", to: "admin#create_user", as: "create_user"
  get "admin/new_user", to: "admin#new_user", as: "new_user"

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
