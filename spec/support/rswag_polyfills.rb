# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Temporary polyfills for rswag 3.0.0.pre compatibility.
# TODO: Remove this file when upgrading to a stable rswag 3.x that includes
# request_body_json natively and resolves let-based parameters without shims.

module Rswag
  module Specs
    # Polyfill request_body_json for rswag 3.0.0.pre which lacks this helper.
    # Wraps the existing `consumes` + `parameter in: :body` mechanism so specs
    # use the OAS 3.0 requestBody DSL while the formatter converts to valid output.
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

    # Patch RequestFactory to wrap @params and @headers with LetFallbackHash,
    # restoring let-block resolution that rswag 3.x replaced with request_params.
    module RequestFactoryLetFallback
      def initialize(metadata, example, config = ::Rswag::Specs.config)
        super
        @params = LetFallbackHash.new(@params, example)
        # Header parameters (e.g., Authorization) are also resolved from `let` blocks
        # and need the same fallback behavior as body/query params.
        @headers = LetFallbackHash.new(@headers, example)
      end
    end

    rswag_version = Gem.loaded_specs["rswag-specs"]&.version&.to_s
    unless rswag_version == "3.0.0.pre"
      raise "rswag-specs version changed to #{rswag_version || 'unknown'}. " \
            "Remove spec/support/rswag_polyfills.rb and verify " \
            "request_body_json is natively supported."
    end

    RequestFactory.prepend(RequestFactoryLetFallback)
  end
end
