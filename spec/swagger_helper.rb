# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# Polyfill request_body_json for rswag 3.0.0.pre which lacks this helper.
# Wraps the existing `consumes` + `parameter in: :body` mechanism so specs
# use the OAS 3.0 requestBody DSL while the formatter converts to valid output.
# TODO: Remove this polyfill when upgrading to a stable rswag 3.x that includes request_body_json natively.
module Rswag
  module Specs
    module ExampleGroupHelpers
      def request_body_json(schema:, required: true, description: nil, examples: nil)
        unless metadata.key?(:operation)
          raise ArgumentError,
                "request_body_json must be called inside an HTTP method block (post, put, patch), not at the path level"
        end

        consumes "application/json"

        param_name = examples || :_request_body
        attrs = { name: param_name, in: :body, schema: schema, required: required }
        attrs[:description] = description if description

        parameter(attrs)
      end
    end

    # Bridge rswag 2.x `let`-based parameter resolution to 3.x `request_params`
    # hash lookups. rswag 3.0.0.pre resolves parameters via params.fetch(name)
    # from example.request_params (empty by default). This wrapper falls back to
    # example.public_send(name) so that existing `let` blocks continue to work.
    # NOTE: Avoid using parameter names that collide with RSpec internals
    # (e.g., :subject, :response, :described_class, :metadata).
    class LetFallbackHash
      def initialize(base_hash, example)
        @base = base_hash
        @example = example
      end

      def fetch(key, *args, &)
        return @base.fetch(key, *args, &) if @base.key?(key)
        return @example.public_send(key.to_sym) if @example.respond_to?(key.to_sym)

        # Neither base nor example has the key — delegate to Hash#fetch for
        # standard default/block/KeyError behavior.
        @base.fetch(key, *args, &)
      end

      def key?(key)
        @base.key?(key) || @example.respond_to?(key.to_sym)
      end

      def method_missing(method, ...)
        @base.public_send(method, ...)
      end

      def respond_to_missing?(method, include_private = false)
        @base.respond_to?(method, include_private) || super
      end
    end

    class RequestFactory
      rswag_version = Gem.loaded_specs["rswag-specs"]&.version&.to_s
      unless rswag_version == "3.0.0.pre"
        raise "rswag-specs version changed to #{rswag_version || 'unknown'}. " \
              "Remove the LetFallbackHash monkey-patch in swagger_helper.rb " \
              "and verify request_body_json is natively supported."
      end

      alias_method :original_initialize, :initialize

      def initialize(metadata, example, config = ::Rswag::Specs.config)
        original_initialize(metadata, example, config)
        @params = LetFallbackHash.new(@params, example)
        # Header parameters (e.g., Authorization) are also resolved from `let` blocks
        # and need the same fallback behavior as body/query params.
        @headers = LetFallbackHash.new(@headers, example)
      end
    end
  end
end

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join("swagger").to_s

  # rswag 3.0.0.pre replaced openapi_strict_schema_validation with granular options.
  # Rely on vacuum linter (just lint-api) for OpenAPI document structure validation.
  config.openapi_no_additional_properties = true

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
          maxElapsedTime: 3600000, # 60 minutes
          exponent: 1.5
        },
        statusCodes: ["5XX", 429],
        retryConnectionErrors: true
      },
      tags: [
        { name: "Agents", description: "Agents API" },
        { name: "Attacks", description: "Attacks API" },
        { name: "Client", description: "Client API" },
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
              default: "cipherswarm.com"
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
            scheme: :bearer,
            description: "Bearer token authentication using agent API tokens"
          }
        },
        schemas: {
          ErrorObject: {
            type: "object",
            description: "Standard error response returned by all API endpoints",
            properties: {
              error: { type: :string }
            },
            required: [:error],
            additionalProperties: true
          },
          Agent: {
            type: :object,
            description: "A cracking agent registered with CipherSwarm",
            properties: {
              id: { type: :integer, format: :int64, description: "The id of the agent" },
              host_name: { type: :string, description: "The hostname of the agent" },
              client_signature: { type: :string, description: "The signature of the client" },
              state: { type: :string, description: "The state of the agent",
                       enum: Agent.state_machine.states.map { |s| s.name.to_s }.sort },
              operating_system: { type: :string, description: "The operating system of the agent" },
              devices: { type: :array, items: { type: :string, description: "The descriptive name of a GPU or CPU device." } },
              current_activity: { type: :string, nullable: true, description: "Current agent activity state" },
              advanced_configuration: {
                "$ref" => "#/components/schemas/AdvancedAgentConfiguration"
              }
            },
            required: %i[id host_name client_signature operating_system devices state advanced_configuration]
          },
          AdvancedAgentConfiguration: {
            type: :object,
            description: "Advanced hashcat and agent configuration options",
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
            description: "A single hashcat benchmark result for a specific hash type and device",
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
            description: "A hashcat attack configuration assigned to an agent",
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
                description: "A hashcat mask string",
                nullable: true
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
          HashcatResult: {
            type: :object,
            description: "A cracked hash result submitted by an agent",
            properties: {
              timestamp: { type: :string, format: "date-time", description: "The time the hash was cracked" },
              hash: { type: :string, description: "The hash value" },
              plain_text: { type: :string, description: "The plain text value" }
            },
            required: %i[timestamp hash plain_text]
          },
          Task: {
            type: :object,
            description: "A unit of work assigned to an agent for a specific attack",
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
            description: "A downloadable resource file (word list, rule list, or mask list) used by an attack",
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
            description: "A hashcat status update submitted by an agent during task execution",
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
            description: "Status and performance metrics for a single GPU or CPU device",
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
            description: "Current hashcat guess progress including base and modifier values",
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
