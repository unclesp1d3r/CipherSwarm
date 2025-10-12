# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

Rails.application.config.after_initialize do
  Turbo::Streams::BroadcastStreamJob.class_eval do
    def self.perform_later(stream, content:)
      super(stream, content: content.to_str)
    end
  end
end
