# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# Turbo::Streams::BroadcastStreamJob passes an ActiveSupport::SafeBuffer as the
# `content:` keyword argument. Sidekiq serializes job arguments as JSON, and
# SafeBuffer#to_json includes extra metadata that causes deserialization failures.
# Calling `.to_str` converts it to a plain String before enqueuing.
#
# This was fixed upstream in turbo-rails >= 2.0.11. Remove this patch once
# turbo-rails is upgraded past that version.
#
# See: https://github.com/hotwired/turbo-rails/issues/631

Rails.application.config.after_initialize do
  turbo_version = Gem::Version.new(Gem.loaded_specs["turbo-rails"]&.version.to_s)
  if turbo_version < Gem::Version.new("2.0.11")
    Turbo::Streams::BroadcastStreamJob.class_eval do
      def self.perform_later(stream, content:)
        super(stream, content: content.to_str)
      end
    end
  end
end
