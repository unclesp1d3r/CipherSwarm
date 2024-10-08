# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
        strategy: :backoff,
        backoff: {
          initialInterval: 500, # 500 milliseconds
          maxInterval: 60000, # 60 seconds
          maxElapsedTime: 3600000, # 5 minutes
          exponent: 1.5
        },
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
        title: "CipherSwarm Agent API",
        description: "The CipherSwarm Agent API is used to allow agents to connect to the CipherSwarm server.",
        version: "1.3",
        license: {
          name: "Mozilla Public License Version 2.0",
          url: "https://www.mozilla.org/en-US/MPL/2.0/"
        }
      },
      servers: [
        {
          url: "https://{defaultHost}",
          description: "The production server",
          variables: {
            defaultHost: {
              default: "www.example.com"
            }
          }
        },
        {
          url: "http://{hostAddress}:{hostPort}",
          description: "The insecure server",
          variables: {
            hostAddress: {
              default: "localhost"
            },
            hostPort: {
              default: "8080"
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
          Agent: {
            type: :object,
            properties: {
              id: { type: :integer, format: :int64, description: "The id of the agent" },
              host_name: { type: :string, description: "The hostname of the agent" },
              client_signature: { type: :string, description: "The signature of the client" },
              state: { type: :string, description: "The state of the agent",
                       enum: %w[pending active stopped error] },
              operating_system: { type: :string, description: "The operating system of the agent" },
              devices: { type: :array, items: { type: :string, description: "The descriptive name of a GPU or CPU device." } },
              advanced_configuration: {
                "$ref" => "#/components/schemas/AdvancedAgentConfiguration"
              }
            },
            required: %i[id host_name client_signature operating_system devices state advanced_configuration]
          },
          AdvancedAgentConfiguration: {
            type: :object,
            properties: {
              agent_update_interval: { type: :integer, nullable: true, description: "The interval in seconds to check for agent updates" },
              use_native_hashcat: { type: :boolean, nullable: true, description: "Use the hashcat binary already installed on the client system" },
              backend_device: { type: :string, nullable: true, description: "The device to use for hashcat, separated by commas" },
              opencl_devices: { type: :string, nullable: true, description: "The OpenCL device types to use for hashcat, separated by commas" },
              enable_additional_hash_types: { type: :boolean,
                                              description: "Causes hashcat to perform benchmark-all, rather than just benchmark" }
            },
            required: %i[agent_update_interval use_native_hashcat backend_device enable_additional_hash_types]
          },

          HashcatBenchmark: {
            type: :object,
            properties: {
              hash_type: { type: :integer, description: "The hashcat hash type" },
              runtime: { type: :integer, format: :int64, description: "The runtime of the benchmark in milliseconds." },
              hash_speed: { type: :number, format: :double, description: "The speed of the benchmark in hashes per second." },
              device: { type: :integer, description: "The device used for the benchmark" }
            },
            required: %i[hash_type runtime hash_speed device]
          },
          Attack: {
            type: :object,
            properties: {
              id: {
                type: :integer,
                format: "int64",
                description: "The id of the attack",
                nullable: false
              },
              attack_mode: {
                type: :string,
                default: "dictionary",
                description: "Attack mode name",
                enum: %i[dictionary mask hybrid_dictionary hybrid_mask],
                nullable: false
              },
              attack_mode_hashcat: {
                type: :integer,
                default: 0,
                minimum: 0,
                maximum: 7,
                description: "hashcat attack mode",
                nullable: false
              },
              mask: {
                type: :string,
                default: "",
                description: "A hashcat mask string"
              },
              increment_mode: {
                type: :boolean,
                default: false,
                description: "Enable hashcat increment mode",
                nullable: false
              },
              increment_minimum: {
                type: :integer,
                minimum: 0,
                description: "The start of the increment range",
                nullable: false
              },
              increment_maximum: {
                type: :integer,
                minimum: 0,
                maximum: 62,
                description: "The end of the increment range",
                nullable: false
              },
              optimized: {
                type: :boolean,
                default: false,
                description: "Enable hashcat optimized mode",
                nullable: false
              },
              slow_candidate_generators: {
                type: :boolean,
                default: false,
                description: "Enable hashcat slow candidate generators",
                nullable: false
              },
              workload_profile: {
                type: :integer,
                default: 3,
                minimum: 1,
                maximum: 4,
                description: "The hashcat workload profile",
                nullable: false
              },
              disable_markov: {
                type: :boolean,
                default: false,
                description: "Disable hashcat markov mode",
                nullable: false
              },
              classic_markov: {
                type: :boolean,
                default: false,
                description: "Enable hashcat classic markov mode",
                nullable: false
              },
              markov_threshold: {
                type: :integer,
                default: 0,
                description: "The hashcat markov threshold"

              },
              left_rule: {
                type: :string,
                default: "",
                description: "The left-hand rule for combinator attacks",
                nullable: true
              },
              right_rule: {
                type: :string,
                default: "",
                description: "The right-hand rule for combinator attacks",
                nullable: true
              },
              custom_charset_1: {
                type: :string,
                default: "",
                description: "Custom charset 1 for hashcat mask attacks",
                nullable: true
              },
              custom_charset_2: {
                type: :string,
                default: "",
                description: "Custom charset 2 for hashcat mask attacks",
                nullable: true
              },
              custom_charset_3: {
                type: :string,
                default: "",
                description: "Custom charset 3 for hashcat mask attacks",
                nullable: true
              },
              custom_charset_4: {
                type: :string,
                default: "",
                description: "Custom charset 4 for hashcat mask attacks",
                nullable: true
              },
              hash_list_id: {
                type: :integer,
                format: "int64",
                description: "The id of the hash list",
                nullable: false
              },
              word_list: {
                "$ref" => "#/components/schemas/AttackResourceFile"
              },
              rule_list: {
                "$ref" => "#/components/schemas/AttackResourceFile"
              },
              mask_list: {
                "$ref" => "#/components/schemas/AttackResourceFile"
              },
              hash_mode: {
                type: :integer,
                default: 0,
                description: "The hashcat hash mode",
                nullable: false
              },
              hash_list_url: {
                type: :string,
                format: :uri,
                description: "The download URL for the hash list",
                nullable: true
              },
              hash_list_checksum: {
                type: :string,
                format: :byte,
                description: "The MD5 checksum of the hash list",
                nullable: true
              },
              url: {
                type: :string,
                format: :uri,
                description: "The URL to the attack",
                nullable: true
              }
            },
            required: %i[
              id
              attack_mode
              attack_mode_hashcat
              classic_markov
              disable_markov
              increment_minimum
              increment_maximum
              increment_mode
              optimized
              slow_candidate_generators
              workload_profile
              hash_list_id
              hash_mode
              hash_list_url
              hash_list_checksum
              url
            ]
          },
          CrackerUpdate: {
            type: :object,
            properties: {
              available: { type: :boolean, description: "A new version of the cracker binary is available" },
              latest_version: { type: :string, nullable: true, description: "The latest version of the cracker binary" },
              download_url: { type: :string, format: :uri, nullable: true, description: "The download URL of the new version" },
              exec_name: { type: :string, nullable: true, description: "The name of the executable" },
              message: { type: :string, nullable: true, description: "A message about the update" }
            },
            required: %i[available]
          },
          HashcatResult: {
            type: :object,
            properties: {
              timestamp: { type: :string, format: "date-time", description: "The time the hash was cracked" },
              hash: { type: :string, description: "The hash value" },
              plain_text: { type: :string, description: "The plain text value" }
            },
            required: %i[timestamp hash plain_text]
          },
          Task: {
            type: :object,
            properties: {
              id: { type: :integer, format: :int64, description: "The id of the task" },
              attack_id: { type: :integer, format: :int64, description: "The id of the attack" },
              start_date: { type: :string, format: "date-time", description: "The time the task was started" },
              status: { type: :string, description: "The status of the task" },
              skip: { type: :integer, format: :int64, nullable: true, description: "The offset of the keyspace" },
              limit: { type: :integer, format: :int64, nullable: true, description: "The limit of the keyspace" }
            },
            required: %i[id attack_id start_date status]
          },
          AttackResourceFile: {
            type: :object,
            properties: {
              id: { type: :integer, format: :int64, description: "The id of the resource file" },
              download_url: { type: :string, format: :uri, description: "The download URL of the resource file" },
              checksum: { type: :string, format: :byte, description: "The MD5 checksum of the resource file" },
              file_name: { type: :string, description: "The name of the resource file" }
            },
            nullable: true,
            required: %i[id download_url checksum file_name]
          },
          TaskStatus: {
            type: :object,
            properties: {
              original_line: { type: :string, description: "The original line from hashcat" },
              time: { type: :string, format: "date-time", description: "The time the status was received" },
              session: { type: :string, description: "The session name" },
              hashcat_guess: { "$ref" => "#/components/schemas/HashcatGuess" },
              status: { type: :integer, description: "The status of the task" },
              target: { type: :string, description: "The target of the task" },
              progress: { type: :array, items: { type: :integer, format: :int64 }, description: "The progress of the task" },
              restore_point: { type: :integer, format: :int64, description: "The restore point of the task" },
              recovered_hashes: { type: :array, items: { type: :integer }, description: "The number of recovered hashes" },
              recovered_salts: { type: :array, items: { type: :integer }, description: "The number of recovered salts" },
              rejected: { type: :integer, format: :int64, description: "The number of rejected guesses" },
              device_statuses: { type: :array, items: { "$ref" => "#/components/schemas/DeviceStatus" },
                                 description: "The status of the devices used for the task" },
              time_start: { type: :string, format: "date-time", description: "The time the task started." },
              estimated_stop: { type: :string, format: "date-time", description: "The estimated time of completion." }
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
              device_id: { type: :integer, description: "The id of the device" },
              device_name: { type: :string, description: "The name of the device" },
              device_type: { type: :string, description: "The type of the device", enum: %w[CPU GPU] },
              speed: { type: :integer, format: :int64, description: "The speed of the device" },
              utilization: { type: :integer, description: "The utilization of the device" },
              temperature: { type: :integer, description: "The temperature of the device, or -1 if unmonitored." }
            },
            required: %i[device_id device_name device_type speed utilization temperature]
          },
          HashcatGuess: {
            type: :object,
            properties: {
              guess_base: { type: :string, description: "The base value used for the guess (for example, the mask)" },
              guess_base_count: { type: :integer, format: :int64, description: "The number of times the base value was used" },
              guess_base_offset: { type: :integer, format: :int64, description: "The offset of the base value" },
              guess_base_percentage: { type: :number, format: :double, description: "The percentage completion of the base value" },
              guess_mod: { type: :string, description: "The modifier used for the guess (for example, the wordlist)" },
              guess_mod_count: { type: :integer, format: :int64, description: "The number of times the modifier was used" },
              guess_mod_offset: { type: :integer, format: :int64, description: "The offset of the modifier" },
              guess_mod_percentage: { type: :number, format: :double, description: "The percentage completion of the modifier" },
              guess_mode: { type: :integer, description: "The mode used for the guess" }
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

  config.after(:each, operation: true, use_as_request_example: true) do |spec|
    spec.metadata[:operation][:request_examples] ||= []

    next if request.body.blank?

    example = {
      value: JSON.parse(request.body, symbolize_names: true),
      name: "request_example_1",
      summary: "A request example"
    }

    spec.metadata[:operation][:request_examples] << example
  end

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  # config.openapi_format = :json
end
