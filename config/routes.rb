# frozen_string_literal: true

# == Route Map
#
#                                          Prefix Verb   URI Pattern                                                                                       Controller#Action
#                                        rswag_ui        /api-docs                                                                                         Rswag::Ui::Engine
#                                       rswag_api        /api-docs                                                                                         Rswag::Api::Engine
#                                    admin_agents GET    /admin/agents(.:format)                                                                           admin/agents#index
#                                                 POST   /admin/agents(.:format)                                                                           admin/agents#create
#                                 new_admin_agent GET    /admin/agents/new(.:format)                                                                       admin/agents#new
#                                edit_admin_agent GET    /admin/agents/:id/edit(.:format)                                                                  admin/agents#edit
#                                     admin_agent GET    /admin/agents/:id(.:format)                                                                       admin/agents#show
#                                                 PATCH  /admin/agents/:id(.:format)                                                                       admin/agents#update
#                                                 PUT    /admin/agents/:id(.:format)                                                                       admin/agents#update
#                                                 DELETE /admin/agents/:id(.:format)                                                                       admin/agents#destroy
#                                   admin_attacks GET    /admin/attacks(.:format)                                                                          admin/attacks#index
#                                                 POST   /admin/attacks(.:format)                                                                          admin/attacks#create
#                                new_admin_attack GET    /admin/attacks/new(.:format)                                                                      admin/attacks#new
#                               edit_admin_attack GET    /admin/attacks/:id/edit(.:format)                                                                 admin/attacks#edit
#                                    admin_attack GET    /admin/attacks/:id(.:format)                                                                      admin/attacks#show
#                                                 PATCH  /admin/attacks/:id(.:format)                                                                      admin/attacks#update
#                                                 PUT    /admin/attacks/:id(.:format)                                                                      admin/attacks#update
#                                                 DELETE /admin/attacks/:id(.:format)                                                                      admin/attacks#destroy
#                                 admin_campaigns GET    /admin/campaigns(.:format)                                                                        admin/campaigns#index
#                                                 POST   /admin/campaigns(.:format)                                                                        admin/campaigns#create
#                              new_admin_campaign GET    /admin/campaigns/new(.:format)                                                                    admin/campaigns#new
#                             edit_admin_campaign GET    /admin/campaigns/:id/edit(.:format)                                                               admin/campaigns#edit
#                                  admin_campaign GET    /admin/campaigns/:id(.:format)                                                                    admin/campaigns#show
#                                                 PATCH  /admin/campaigns/:id(.:format)                                                                    admin/campaigns#update
#                                                 PUT    /admin/campaigns/:id(.:format)                                                                    admin/campaigns#update
#                                                 DELETE /admin/campaigns/:id(.:format)                                                                    admin/campaigns#destroy
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
#                                admin_mask_lists GET    /admin/mask_lists(.:format)                                                                       admin/mask_lists#index
#                                                 POST   /admin/mask_lists(.:format)                                                                       admin/mask_lists#create
#                             new_admin_mask_list GET    /admin/mask_lists/new(.:format)                                                                   admin/mask_lists#new
#                            edit_admin_mask_list GET    /admin/mask_lists/:id/edit(.:format)                                                              admin/mask_lists#edit
#                                 admin_mask_list GET    /admin/mask_lists/:id(.:format)                                                                   admin/mask_lists#show
#                                                 PATCH  /admin/mask_lists/:id(.:format)                                                                   admin/mask_lists#update
#                                                 PUT    /admin/mask_lists/:id(.:format)                                                                   admin/mask_lists#update
#                                                 DELETE /admin/mask_lists/:id(.:format)                                                                   admin/mask_lists#destroy
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
#                                     admin_tasks GET    /admin/tasks(.:format)                                                                            admin/tasks#index
#                                                 POST   /admin/tasks(.:format)                                                                            admin/tasks#create
#                                  new_admin_task GET    /admin/tasks/new(.:format)                                                                        admin/tasks#new
#                                 edit_admin_task GET    /admin/tasks/:id/edit(.:format)                                                                   admin/tasks#edit
#                                      admin_task GET    /admin/tasks/:id(.:format)                                                                        admin/tasks#show
#                                                 PATCH  /admin/tasks/:id(.:format)                                                                        admin/tasks#update
#                                                 PUT    /admin/tasks/:id(.:format)                                                                        admin/tasks#update
#                                                 DELETE /admin/tasks/:id(.:format)                                                                        admin/tasks#destroy
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
#                                campaign_attacks POST   /campaigns/:campaign_id/attacks(.:format)                                                         attacks#create
#                             new_campaign_attack GET    /campaigns/:campaign_id/attacks/new(.:format)                                                     attacks#new
#                            edit_campaign_attack GET    /campaigns/:campaign_id/attacks/:id/edit(.:format)                                                attacks#edit
#                                 campaign_attack GET    /campaigns/:campaign_id/attacks/:id(.:format)                                                     attacks#show
#                                                 PATCH  /campaigns/:campaign_id/attacks/:id(.:format)                                                     attacks#update
#                                                 PUT    /campaigns/:campaign_id/attacks/:id(.:format)                                                     attacks#update
#                                                 DELETE /campaigns/:campaign_id/attacks/:id(.:format)                                                     attacks#destroy
#                          campaign_toggle_paused POST   /campaigns/:campaign_id/toggle_paused(.:format)                                                   campaigns#toggle_paused
#                                       campaigns GET    /campaigns(.:format)                                                                              campaigns#index
#                                                 POST   /campaigns(.:format)                                                                              campaigns#create
#                                    new_campaign GET    /campaigns/new(.:format)                                                                          campaigns#new
#                                   edit_campaign GET    /campaigns/:id/edit(.:format)                                                                     campaigns#edit
#                                        campaign GET    /campaigns/:id(.:format)                                                                          campaigns#show
#                                                 PATCH  /campaigns/:id(.:format)                                                                          campaigns#update
#                                                 PUT    /campaigns/:id(.:format)                                                                          campaigns#update
#                                                 DELETE /campaigns/:id(.:format)                                                                          campaigns#destroy
#                toggle_hide_completed_activities GET    /toggle_hide_completed_activities(.:format)                                                       campaigns#toggle_hide_completed_activities
#                                      hash_lists GET    /hash_lists(.:format)                                                                             hash_lists#index
#                                                 POST   /hash_lists(.:format)                                                                             hash_lists#create
#                                   new_hash_list GET    /hash_lists/new(.:format)                                                                         hash_lists#new
#                                  edit_hash_list GET    /hash_lists/:id/edit(.:format)                                                                    hash_lists#edit
#                                       hash_list GET    /hash_lists/:id(.:format)                                                                         hash_lists#show
#                                                 PATCH  /hash_lists/:id(.:format)                                                                         hash_lists#update
#                                                 PUT    /hash_lists/:id(.:format)                                                                         hash_lists#update
#                                                 DELETE /hash_lists/:id(.:format)                                                                         hash_lists#destroy
#                             view_file_word_list GET    /word_lists/:id/view_file(.:format)                                                               word_lists#view_file
#                     view_file_content_word_list GET    /word_lists/:id/view_file_content(.:format)                                                       word_lists#view_file_content
#                              download_word_list GET    /word_lists/:id/download(.:format)                                                                word_lists#download
#                                      word_lists GET    /word_lists(.:format)                                                                             word_lists#index
#                                                 POST   /word_lists(.:format)                                                                             word_lists#create
#                                   new_word_list GET    /word_lists/new(.:format)                                                                         word_lists#new
#                                  edit_word_list GET    /word_lists/:id/edit(.:format)                                                                    word_lists#edit
#                                       word_list GET    /word_lists/:id(.:format)                                                                         word_lists#show
#                                                 PATCH  /word_lists/:id(.:format)                                                                         word_lists#update
#                                                 PUT    /word_lists/:id(.:format)                                                                         word_lists#update
#                                                 DELETE /word_lists/:id(.:format)                                                                         word_lists#destroy
#                             view_file_rule_list GET    /rule_lists/:id/view_file(.:format)                                                               rule_lists#view_file
#                     view_file_content_rule_list GET    /rule_lists/:id/view_file_content(.:format)                                                       rule_lists#view_file_content
#                              download_rule_list GET    /rule_lists/:id/download(.:format)                                                                rule_lists#download
#                                      rule_lists GET    /rule_lists(.:format)                                                                             rule_lists#index
#                                                 POST   /rule_lists(.:format)                                                                             rule_lists#create
#                                   new_rule_list GET    /rule_lists/new(.:format)                                                                         rule_lists#new
#                                  edit_rule_list GET    /rule_lists/:id/edit(.:format)                                                                    rule_lists#edit
#                                       rule_list GET    /rule_lists/:id(.:format)                                                                         rule_lists#show
#                                                 PATCH  /rule_lists/:id(.:format)                                                                         rule_lists#update
#                                                 PUT    /rule_lists/:id(.:format)                                                                         rule_lists#update
#                                                 DELETE /rule_lists/:id(.:format)                                                                         rule_lists#destroy
#                             view_file_mask_list GET    /mask_lists/:id/view_file(.:format)                                                               mask_lists#view_file
#                     view_file_content_mask_list GET    /mask_lists/:id/view_file_content(.:format)                                                       mask_lists#view_file_content
#                              download_mask_list GET    /mask_lists/:id/download(.:format)                                                                mask_lists#download
#                                      mask_lists GET    /mask_lists(.:format)                                                                             mask_lists#index
#                                                 POST   /mask_lists(.:format)                                                                             mask_lists#create
#                                   new_mask_list GET    /mask_lists/new(.:format)                                                                         mask_lists#new
#                                  edit_mask_list GET    /mask_lists/:id/edit(.:format)                                                                    mask_lists#edit
#                                       mask_list GET    /mask_lists/:id(.:format)                                                                         mask_lists#show
#                                                 PATCH  /mask_lists/:id(.:format)                                                                         mask_lists#update
#                                                 PUT    /mask_lists/:id(.:format)                                                                         mask_lists#update
#                                                 DELETE /mask_lists/:id(.:format)                                                                         mask_lists#destroy
#                                cracker_binaries GET    /cracker_binaries(.:format)                                                                       cracker_binaries#index
#                                                 POST   /cracker_binaries(.:format)                                                                       cracker_binaries#create
#                              new_cracker_binary GET    /cracker_binaries/new(.:format)                                                                   cracker_binaries#new
#                             edit_cracker_binary GET    /cracker_binaries/:id/edit(.:format)                                                              cracker_binaries#edit
#                                  cracker_binary GET    /cracker_binaries/:id(.:format)                                                                   cracker_binaries#show
#                                                 PATCH  /cracker_binaries/:id(.:format)                                                                   cracker_binaries#update
#                                                 PUT    /cracker_binaries/:id(.:format)                                                                   cracker_binaries#update
#                                                 DELETE /cracker_binaries/:id(.:format)                                                                   cracker_binaries#destroy
# api_v1_client_crackers_check_for_cracker_update GET    /api/v1/client/crackers/check_for_cracker_update(.:format)                                        api/v1/client/crackers#check_for_cracker_update {:format=>:json}
#                     api_v1_client_configuration GET    /api/v1/client/configuration(.:format)                                                            api/v1/client#configuration {:format=>:json}
#                      api_v1_client_authenticate GET    /api/v1/client/authenticate(.:format)                                                             api/v1/client#authenticate {:format=>:json}
#                             api_v1_client_agent GET    /api/v1/client/agents/:id(.:format)                                                               api/v1/client/agents#show {:format=>:json}
#                                                 PATCH  /api/v1/client/agents/:id(.:format)                                                               api/v1/client/agents#update {:format=>:json}
#                                                 PUT    /api/v1/client/agents/:id(.:format)                                                               api/v1/client/agents#update {:format=>:json}
#                  api_v1_client_agents_heartbeat POST   /api/v1/client/agents/:id/heartbeat(.:format)                                                     api/v1/client/agents#heartbeat {:format=>:json}
#           api_v1_client_agents_submit_benchmark POST   /api/v1/client/agents/:id/submit_benchmark(.:format)                                              api/v1/client/agents#submit_benchmark {:format=>:json}
#               api_v1_client_agents_submit_error POST   /api/v1/client/agents/:id/submit_error(.:format)                                                  api/v1/client/agents#submit_error {:format=>:json}
#                   api_v1_client_agents_shutdown POST   /api/v1/client/agents/:id/shutdown(.:format)                                                      api/v1/client/agents#shutdown {:format=>:json}
#                            api_v1_client_attack GET    /api/v1/client/attacks/:id(.:format)                                                              api/v1/client/attacks#show {:format=>:json}
#                  api_v1_client_attack_hash_list GET    /api/v1/client/attacks/:id/hash_list(.:format)                                                    api/v1/client/attacks#hash_list {:format=>:json}
#                          new_api_v1_client_task GET    /api/v1/client/tasks/new(.:format)                                                                api/v1/client/tasks#new {:format=>:json}
#                              api_v1_client_task GET    /api/v1/client/tasks/:id(.:format)                                                                api/v1/client/tasks#show {:format=>:json}
#                                                 PATCH  /api/v1/client/tasks/:id(.:format)                                                                api/v1/client/tasks#update {:format=>:json}
#                                                 PUT    /api/v1/client/tasks/:id(.:format)                                                                api/v1/client/tasks#update {:format=>:json}
#                 api_v1_client_task_submit_crack POST   /api/v1/client/tasks/:id/submit_crack(.:format)                                                   api/v1/client/tasks#submit_crack {:format=>:json}
#                api_v1_client_task_submit_status POST   /api/v1/client/tasks/:id/submit_status(.:format)                                                  api/v1/client/tasks#submit_status {:format=>:json}
#                  api_v1_client_task_accept_task POST   /api/v1/client/tasks/:id/accept_task(.:format)                                                    api/v1/client/tasks#accept_task {:format=>:json}
#                    api_v1_client_task_exhausted POST   /api/v1/client/tasks/:id/exhausted(.:format)                                                      api/v1/client/tasks#exhausted {:format=>:json}
#                      api_v1_client_task_abandon POST   /api/v1/client/tasks/:id/abandon(.:format)                                                        api/v1/client/tasks#abandon {:format=>:json}
#                     api_v1_client_task_get_zaps GET    /api/v1/client/tasks/:id/get_zaps(.:format)                                                       api/v1/client/tasks#get_zaps {:format=>:json}
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
#                          edit_user_registration GET    /users/edit(.:format)                                                                             devise/registrations#edit
#                               user_registration PUT    /users(.:format)                                                                                  devise/registrations#update
#                              rails_health_check GET    /up(.:format)                                                                                     rails/health#show
#                              pwa_service_worker GET    /service-worker(.:format)                                                                         rails/pwa#service_worker
#                                    pwa_manifest GET    /manifest(.:format)                                                                               rails/pwa#manifest
#                              authenticated_root GET    /                                                                                                 home#index
#                                     sidekiq_web        /sidekiq                                                                                          Sidekiq::Web
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
#
# Routes for Rswag::Ui::Engine:
#
#
# Routes for Rswag::Api::Engine:

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "sidekiq/web"
Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  concern :downloadable do
    member do
      get :view_file
      get :view_file_content
      get :download
    end
  end

  draw(:admin)
  resources :campaigns do
    resources :attacks, only: %i[ create new edit show update destroy ]
    post "toggle_paused"
    member do
      get :eta_summary
      get :recent_cracks
      get :error_log
    end
  end
  get "toggle_hide_completed_activities" => "campaigns#toggle_hide_completed_activities"

  resources :tasks, only: %i[show] do
    member do
      post :cancel
      post :retry
      post :reassign
      get :logs
      get :download_results
    end
  end

  resources :hash_lists
  resources :word_lists, :rule_lists, :mask_lists, concerns: :downloadable
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      draw(:client_api)
    end
  end

  resources :agents do
    collection do
      get :cards
    end
  end
  resources :projects, only: %i[ show new create edit update destroy ]

  # Define the admin routes
  get "admin/index"
  post "admin/unlock_user/:id", to: "admin#unlock_user", as: "unlock_user"
  post "admin/lock_user/:id", to: "admin#lock_user", as: "lock_user"
  post "admin/create_user", to: "admin#create_user", as: "create_user"
  get "admin/new_user", to: "admin#new_user", as: "new_user"

  draw(:errors)
  draw(:devise)

  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  authenticated :user do
    root to: "home#index", as: :authenticated_root
  end

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  root to: redirect("/users/sign_in")
end
