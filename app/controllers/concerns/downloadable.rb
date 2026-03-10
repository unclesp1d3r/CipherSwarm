# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The Downloadable module provides a set of methods for managing the download
# and viewing of files associated with a resource in a Rails application.
#
# This module relies on the ActiveSupport::Concern module to define reusable
# shared behavior. It includes methods for downloading files, rendering a
# view of a file, and rendering the contents of a file with optional line
# limits.
module Downloadable
  extend ActiveSupport::Concern

  def download
    @resource = resource_class.find(params[:id])
    authorize! :read, @resource

    redirect_to rails_blob_url @resource.file
  end

  def view_file
    @resource = resource_class.find(params[:id])
    authorize! :view_file, @resource

    render "shared/attack_resource/view_file"
  end

  def view_file_content
    @resource = resource_class.find(params[:id])
    authorize! :view_file_content, @resource

    max_lines = [(params[:limit].presence || 1000).to_i, 5000].min
    lines = []
    @resource.file.blob.open do |file|
      file.each_line do |line|
        break if lines.size >= max_lines

        lines << line
      end
    end
    @file_content = lines.join
    render turbo_stream: turbo_stream.replace(:file_content,
                                              partial: "shared/attack_resource/file_content",
                                              locals: { file_content: @file_content })
  end

  private

  def resource_class
    controller_path.classify.constantize
  rescue NameError => e
    raise ArgumentError,
      "Downloadable: cannot resolve model from controller_path '#{controller_path}'. " \
      "Ensure the controller name maps to a valid model. (#{e.message})"
  end
end
