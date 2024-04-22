# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_strict_schema_validation = true

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    "v1/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "API V1",
        version: "v1"
      },
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer
          }
        },
        schemas: {
          error_object: {
            type: "object",
            properties: {
              error: { type: :string }
            }
          },
          errors_object: {
            type: "object",
            properties: {
              errors: { "$ref" => "#/components/schemas/errors_map" }
            }
          },
          errors_map: {
            type: "object",
            additionalProperties: {
              type: "array",
              items: { type: "string" }
            }
          },
          advanced_agent_configuration: {
            type: :object,
            properties: {
              agent_update_interval: { type: :integer, nullable: true },
              use_native_hashcat: { type: :boolean, nullable: true },
              backend_device: { type: :string, nullable: true }
            }
          },
          agent: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              client_signature: { type: :string },
              command_parameters: { type: :string, nullable: true },
              cpu_only: { type: :boolean },
              trusted: { type: :boolean },
              ignore_errors: { type: :boolean },
              operating_system: { type: :string },
              devices: { type: :array, items: { type: :string } },
              advanced_configuration: {
                ref: "#/components/schemas/AdvancedAgentConfiguration",
                nullable: true
              }
            }
          },
          attack: {
            type: :object,
            required: %w[id attack_mode mask increment_mode increment_minimum increment_maximum optimized
              slow_candidate_generators workload_profile disable_markov classic_markov markov_threshold left_rule right_rule custom_charset_1 custom_charset_2 custom_charset_3 custom_charset_4 hash_list_id word_lists rule_lists hash_mode hash_list_url hash_list_checksum url],
            properties: {
              id: {
                type: :integer,
                default: 0,
                title: "The id Schema"

              },
              attack_mode: {
                type: :string,
                default: "",
                title: "The attack_mode Schema",
                examples: [
                  "dictionary"
                ]
              },
              mask: {
                type: :string,
                default: "",
                title: "The mask Schema",
                examples: [
                  "?a?a?a?a?a?a?a?a"
                ]
              },
              increment_mode: {
                type: :boolean,
                default: false,
                title: "The increment_mode Schema"

              },
              increment_minimum: {
                type: :integer,
                default: 0,
                title: "The increment_minimum Schema"

              },
              increment_maximum: {
                type: :integer,
                default: 0,
                title: "The increment_maximum Schema"

              },
              optimized: {
                type: :boolean,
                default: false,
                title: "The optimized Schema"

              },
              slow_candidate_generators: {
                type: :boolean,
                default: false,
                title: "The slow_candidate_generators Schema"

              },
              workload_profile: {
                type: :integer,
                default: 0,
                title: "The workload_profile Schema"

              },
              disable_markov: {
                type: :boolean,
                default: false,
                title: "The disable_markov Schema"

              },
              classic_markov: {
                type: :boolean,
                default: false,
                title: "The classic_markov Schema"

              },
              markov_threshold: {
                type: :integer,
                default: 0,
                title: "The markov_threshold Schema"

              },
              left_rule: {
                type: :string,
                default: "",
                title: "The left_rule Schema",
                nullable: true
              },
              right_rule: {
                type: :string,
                default: "",
                title: "The right_rule Schema",
                nullable: true
              },
              custom_charset_1: {
                type: :string,
                default: "",
                title: "The custom_charset_1 Schema",
                nullable: true
              },
              custom_charset_2: {
                type: :string,
                default: "",
                title: "The custom_charset_2 Schema",
                nullable: true
              },
              custom_charset_3: {
                type: :string,
                default: "",
                title: "The custom_charset_3 Schema",
                nullable: true
              },
              custom_charset_4: {
                type: :string,
                default: "",
                title: "The custom_charset_4 Schema",
                nullable: true
              },
              hash_list_id: {
                type: :integer,
                default: 0,
                title: "The hash_list_id Schema"

              },
              word_lists: {
                type: "array",
                default: [],
                title: "The word_lists Schema",
                items: {}
              },
              rule_lists: {
                type: "array",
                default: [],
                title: "The rule_lists Schema",
                items: {}
              },
              hash_mode: {
                type: :integer,
                default: 0,
                title: "The hash_mode Schema"
              },
              hash_list_url: {
                type: :string,
                default: "",
                title: "The hash_list_url Schema",
                examples: [
                  "http://www.example.com/api/v1/client/attacks/129/hash_list"
                ]
              },
              hash_list_checksum: {
                type: :string,
                default: "",
                title: "The hash_list_checksum Schema",
                examples: [
                  "1B2M2Y8AsgTpgAmY7PhCfg=="
                ]
              },
              url: {
                type: :string,
                default: "",
                title: "The url Schema",
                examples: [
                  "http://www.example.com/attacks/129.json"
                ]
              }
            }
          },
          cracker_binary: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              version: { type: :string },
              archive_file: { type: :string },
              operating_systems: { type: :array, items: { type: :string } }
            },
            required: %w[name version archive_file operating_systems]
          },
          cracker_update: {
            type: :object,
            properties: {
              available: { type: :boolean },
              latest_version: { type: :string, nullable: true },
              download_url: { type: :string, nullable: true },
              exec_name: { type: :string, nullable: true },
              message: { type: :string, nullable: true }
            },
            required: %w[available]
          },
          hashcat_benchmark: {
            type: :object,
            properties: {
              hash_type: { type: :integer },
              runtime: { type: :integer },
              hash_speed: { type: :number },
              device: { type: :integer }
            },
            required: %w[hash_type runtime hash_speed device]
          },
          hashcat_result: {
            type: :object,
            properties: {
              timestamp: { type: :string, format: "date-time" },
              hash: { type: :string },
              plain_text: { type: :string }
            },
            required: %w[timestamp hash plain_text]
          },
          task: {
            type: :object,
            properties: {
              id: { type: :integer },
              attack_id: { type: :integer },
              start_date: { type: :string, format: "date-time" },
              status: { type: :string },
              skip: { type: :integer, nullable: true },
              limit: { type: :integer, nullable: true }
            },
            required: %w[id attack_id start_date status]
          },
          task_status: {
            type: :object,
            properties: {
              original_line: { type: :string },
              time: { type: :string, format: "date-time" },
              session: { type: :string },
              guess: { "$ref" => "#/components/schemas/hashcat_guess" },
              status: { type: :integer },
              target: { type: :string },
              progress: { type: :array, items: { type: :integer } },
              restore_point: { type: :integer },
              recovered_hashes: { type: :array, items: { type: :integer } },
              recovered_salts: { type: :array, items: { type: :integer } },
              rejected: { type: :integer },
              devices: { type: :array, items: { "$ref" => "#/components/schemas/device_status" } },
              time_start: { type: :integer, title: "The time the task started (as Unix epoc time)" },
              estimated_stop: { type: :integer, title: "The estimated time of completion (as Unix epoc time)" }
            },
            required: %i[
              original_line
              time
              session
              guess
              status
              target
              progress
              restore_point
              recovered_hashes
              recovered_salts
              rejected
              devices
              time_start
              estimated_stop
            ]
          },
          device_status: {
            type: :object,
            properties: {
              device_id: { type: :integer },
              device_name: { type: :string },
              device_type: { type: :string },
              speed: { type: :integer },
              utilization: { type: :integer },
              temperature: { type: :integer }
            }
          },
          hashcat_guess: {
            type: :object,
            properties: {
              guess_base: { type: :string },
              guess_base_count: { type: :integer },
              guess_base_offset: { type: :integer },
              guess_base_percent: { type: :number },
              guess_mod: { type: :string },
              guess_mod_count: { type: :integer },
              guess_mod_offset: { type: :integer },
              guess_mod_percent: { type: :number },
              guess_mode: { type: :integer }
            }
          }
        },
        paths: {},
        servers: [
          {
            url: "https://{defaultHost}",
            variables: {
              defaultHost: {
                default: "www.example.com"
              }
            }
          }
        ]
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  # config.openapi_format = :json
end
