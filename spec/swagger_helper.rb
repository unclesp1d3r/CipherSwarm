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
      "x-speakeasy-retries": {
        strategy: "backoff",
        backoff: {
          initialInterval: 500, # 500 milliseconds
          maxInterval: 60000, # 60 seconds
          maxElapsedTime: 3600000, # 5 minutes
          exponent: 1.5 },
        statusCodes: ["5XX", 429],
        retryConnectionErrors: true
      },
      tags: [
        { name: "Agents", description: "Agents API" },
        { name: "Attacks", description: "Attacks API" },
        { name: "Client", description: "Client API" },
        { name: "Crackers", description: "Crackers API" },
        { name: "Tasks", description: "Tasks API" }
      ],
      info: {
        title: "CypherSwarm Agent API",
        description: "The CypherSwarm Agent API is used to allow agents to connect to the CypherSwarm server.",
        version: "v1",
        license: {
          name: "Mozilla Public License Version 2.0",
          url: "https://www.mozilla.org/en-US/MPL/2.0/"
        }
      },
      servers: [
        {
          url: 'https://{defaultHost}',
          description: 'The production server',
          variables: {
            defaultHost: {
              default: 'www.example.com'
            }
          }
        },
        {
          url: 'http://{hostAddress}:{hostPort}',
          description: 'The insecure server',
          variables: {
            hostAddress: {
              default: 'localhost'
            },
            hostPort: {
              default: '8080'
            }
          }
        }
      ],
      security: [
        bearer_auth: []
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer
          }
        },
        schemas: {
          ErrorObject: {
            type: "object",
            properties: {
              error: { type: :string }
            }
          },
          ErrorsMap: {
            type: "object",
            additionalProperties: {
              type: "array",
              items: { type: "string" }
            }
          },
          StateError: {
            type: :object,
            properties: {
              state: { type: :array, items: { type: :string } }
            }
          },
          Agent: {
            type: :object,
            properties: {
              id: { type: :integer, format: "int64", title: "The id of the agent" },
              name: { type: :string, title: "The hostname of the agent" },
              client_signature: { type: :string, title: "The signature of the client" },
              command_parameters: { type: :string, nullable: true, title: "Additional command line parameters to use for hashcat" },
              cpu_only: { type: :boolean, title: "Use only the CPU for hashcat" },
              trusted: { type: :boolean, title: "The agent is trusted with sensitive hash lists" },
              ignore_errors: { type: :boolean, title: "Ignore errors from the agent" },
              operating_system: { type: :string, title: "The operating system of the agent" },
              devices: { type: :array, items: { type: :string, title: "The descriptive name of a GPU or CPU device." } },
              advanced_configuration: {
                "$ref" => "#/components/schemas/AdvancedAgentConfiguration"
              }
            },
            required: %i[id name client_signature command_parameters cpu_only trusted ignore_errors operating_system devices advanced_configuration]
          },
          AgentUpdate: {
            type: :object,
            properties: {
              id: { type: :integer, format: "int64", title: "The id of the agent" },
              name: { type: :string, title: "The hostname of the agent" },
              client_signature: { type: :string, title: "The signature of the client" },
              operating_system: { type: :string, title: "The operating system of the agent" },
              devices: { type: :array, items: { type: :string, title: "The descriptive name of a GPU or CPU device." } }
            },
            required: %i[id name client_signature operating_system devices]
          },
          AdvancedAgentConfiguration: {
            type: :object,
            properties: {
              agent_update_interval: { type: :integer, nullable: true, title: "The interval in seconds to check for agent updates" },
              use_native_hashcat: { type: :boolean, nullable: true, title: "Use the hashcat binary already installed on the client system" },
              backend_device: { type: :string, nullable: true, title: "The device to use for hashcat" }
            },
            required: %i[agent_update_interval use_native_hashcat backend_device]
          },
          AgentLastBenchmark: {
            type: :object,
            properties: {
              last_benchmark_date: { type: :string, format: "date-time", title: "The date of the last benchmark" }
            },
            required: %i[last_benchmark_date]
          },
          AuthenticationResult: {
            type: :object,
            properties: {
              authenticated: { type: :boolean },
              agent_id: { type: :integer, format: "int64" }
            },
            required: %i[authenticated agent_id]
          },
          AgentConfiguration: {
            type: :object,
            properties: {
              config: {
                "$ref" => "#/components/schemas/AdvancedAgentConfiguration"
              },
              api_version: { type: :integer, title: "The minimum accepted version of the API" }
            },
            required: %i[config api_version]
          },
          HashcatBenchmark: {
            type: :object,
            properties: {
              hash_type: { type: :integer, title: "The hashcat hash type" },
              runtime: { type: :integer, format: "int64", title: "The runtime of the benchmark in milliseconds." },
              hash_speed: { type: :number, format: :float, title: "The speed of the benchmark in hashes per second." },
              device: { type: :integer, title: "The device used for the benchmark" }
            },
            required: %i[hash_type runtime hash_speed device]
          },
          Attack: {
            type: :object,
            properties: {
              id: {
                type: :integer,
                format: "int64",
                title: "The id of the attack"
              },
              attack_mode: {
                type: :string,
                default: "dictionary",
                title: "The hashcat attack mode"
              },
              mask: {
                type: :string,
                default: "",
                title: "A hashcat mask string"
              },
              increment_mode: {
                type: :boolean,
                default: false,
                title: "Enable hashcat increment mode"
              },
              increment_minimum: {
                type: :integer,
                minimum: 0,
                title: "The start of the increment range"

              },
              increment_maximum: {
                type: :integer,
                minimum: 0,
                maximum: 62,
                title: "The end of the increment range"
              },
              optimized: {
                type: :boolean,
                default: false,
                title: "Enable hashcat optimized mode"
              },
              slow_candidate_generators: {
                type: :boolean,
                default: false,
                title: "Enable hashcat slow candidate generators"

              },
              workload_profile: {
                type: :integer,
                default: 3,
                minimum: 1,
                maximum: 4,
                title: "The hashcat workload profile"

              },
              disable_markov: {
                type: :boolean,
                default: false,
                title: "Disable hashcat markov mode"

              },
              classic_markov: {
                type: :boolean,
                default: false,
                title: "Enable hashcat classic markov mode"

              },
              markov_threshold: {
                type: :integer,
                default: 0,
                title: "The hashcat markov threshold"

              },
              left_rule: {
                type: :string,
                default: "",
                title: "The left-hand rule for combinator attacks",
                nullable: true
              },
              right_rule: {
                type: :string,
                default: "",
                title: "The right-hand rule for combinator attacks",
                nullable: true
              },
              custom_charset_1: {
                type: :string,
                default: "",
                title: "Custom charset 1 for hashcat mask attacks",
                nullable: true
              },
              custom_charset_2: {
                type: :string,
                default: "",
                title: "Custom charset 2 for hashcat mask attacks",
                nullable: true
              },
              custom_charset_3: {
                type: :string,
                default: "",
                title: "Custom charset 3 for hashcat mask attacks",
                nullable: true
              },
              custom_charset_4: {
                type: :string,
                default: "",
                title: "Custom charset 4 for hashcat mask attacks",
                nullable: true
              },
              hash_list_id: {
                type: :integer,
                format: "int64",
                title: "The id of the hash list"
              },
              word_lists: {
                type: :array,
                default: [],
                title: "The word lists to use in the attack",
                items: {
                  "$ref" => "#/components/schemas/AttackResourceFile"
                }
              },
              rule_lists: {
                type: :array,
                default: [],
                title: "The rule lists to use in the attack",
                items: {
                  "$ref" => "#/components/schemas/AttackResourceFile"
                }
              },
              hash_mode: {
                type: :integer,
                default: 0,
                title: "The hashcat hash mode"
              },
              hash_list_url: {
                type: :string,
                format: :uri,
                title: "The download URL for the hash list"
              },
              hash_list_checksum: {
                type: :string,
                format: :byte,
                title: "The MD5 checksum of the hash list"
              },
              url: {
                type: :string,
                format: :uri,
                title: "The URL to the attack"
              }
            },
            required: %i[
              id
              attack_mode
              optimized
              slow_candidate_generators
              workload_profile
              hash_list_id
              hash_mode
              url
            ]
          },
          CrackerUpdate: {
            type: :object,
            properties: {
              available: { type: :boolean, title: "A new version of the cracker binary is available" },
              latest_version: { type: :string, nullable: true, title: "The latest version of the cracker binary" },
              download_url: { type: :string, format: :uri, nullable: true, title: "The download URL of the new version" },
              exec_name: { type: :string, nullable: true, title: "The name of the executable" },
              message: { type: :string, nullable: true, title: "A message about the update" }
            },
            required: %i[available]
          },
          HashcatResult: {
            type: :object,
            properties: {
              timestamp: { type: :string, format: "date-time", title: "The time the hash was cracked" },
              hash: { type: :string, title: "The hash value" },
              plain_text: { type: :string, title: "The plain text value" }
            },
            required: %i[timestamp hash plain_text]
          },
          Task: {
            type: :object,
            properties: {
              id: { type: :integer, format: "int64", title: "The id of the task" },
              attack_id: { type: :integer, format: "int64", title: "The id of the attack" },
              start_date: { type: :string, format: "date-time", title: "The time the task was started" },
              status: { type: :string, title: "The status of the task" },
              skip: { type: :integer, format: :int64, nullable: true, title: "The offset of the keyspace" },
              limit: { type: :integer, format: :int64, nullable: true, title: "The limit of the keyspace" }
            },
            required: %i[id attack_id start_date status]
          },
          AttackResourceFile: {
            type: :object,
            properties: {
              id: { type: :integer, format: "int64", title: "The id of the resource file" },
              download_url: { type: :string, format: :uri, title: "The download URL of the resource file" },
              checksum: { type: :string, format: :byte, title: "The MD5 checksum of the resource file" },
              file_name: { type: :string, title: "The name of the resource file" }
            },
            required: %i[id download_url checksum file_name]
          },
          TaskStatus: {
            type: :object,
            properties: {
              original_line: { type: :string, title: "The original line from hashcat" },
              time: { type: :string, format: "date-time", title: "The time the status was received" },
              session: { type: :string, title: "The session name" },
              hashcat_guess: { "$ref" => "#/components/schemas/HashcatGuess" },
              status: { type: :integer, title: "The status of the task" },
              target: { type: :string, title: "The target of the task" },
              progress: { type: :array, items: { type: :integer, format: "int64" }, title: "The progress of the task" },
              restore_point: { type: :integer, format: "int64", title: "The restore point of the task" },
              recovered_hashes: { type: :array, items: { type: :integer }, title: "The number of recovered hashes" },
              recovered_salts: { type: :array, items: { type: :integer }, title: "The number of recovered salts" },
              rejected: { type: :integer, format: "int64", title: "The number of rejected guesses" },
              device_statuses: { type: :array, items: { "$ref" => "#/components/schemas/DeviceStatus" },
                                 title: "The status of the devices used for the task" },
              time_start: { type: :string, format: "date-time", title: "The time the task started." },
              estimated_stop: { type: :string, format: "date-time", title: "The estimated time of completion." }
            },
            required: %i[
              original_line
              time
              session
              hashcat_guess
              status
              target
              progress
              restore_point
              recovered_hashes
              recovered_salts
              rejected
              device_statuses
              time_start
              estimated_stop
            ]
          },
          DeviceStatus: {
            type: :object,
            properties: {
              device_id: { type: :integer, title: "The id of the device" },
              device_name: { type: :string, title: "The name of the device" },
              device_type: { type: :string, title: "The type of the device", enum: %w[CPU GPU] },
              speed: { type: :integer, format: "int64", title: "The speed of the device" },
              utilization: { type: :integer, title: "The utilization of the device" },
              temperature: { type: :integer, title: "The temperature of the device, or -1 if unmonitored." }
            },
            required: %i[device_id device_name device_type speed utilization temperature]
          },
          HashcatGuess: {
            type: :object,
            properties: {
              guess_base: { type: :string, title: "The base value used for the guess (for example, the mask)" },
              guess_base_count: { type: :integer, format: "int64", title: "The number of times the base value was used" },
              guess_base_offset: { type: :integer, format: "int64", title: "The offset of the base value" },
              guess_base_percentage: { type: :number, title: "The percentage completion of the base value" },
              guess_mod: { type: :string, title: "The modifier used for the guess (for example, the wordlist)" },
              guess_mod_count: { type: :integer, format: "int64", title: "The number of times the modifier was used" },
              guess_mod_offset: { type: :integer, format: "int64", title: "The offset of the modifier" },
              guess_mod_percentage: { type: :number, title: "The percentage completion of the modifier" },
              guess_mode: { type: :integer, title: "The mode used for the guess" }
            },
            required: %i[
              guess_base
              guess_base_count
              guess_base_offset
              guess_base_percentage
              guess_mod
              guess_mod_count
              guess_mod_offset
              guess_mod_percentage
              guess_mode]
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  # config.openapi_format = :json
end
