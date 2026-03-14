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

    @effective_limit = [[(params[:limit].presence || 1000).to_i, 1].max, 5000].min
    render "shared/attack_resource/view_file"
  end

  MAX_PREVIEW_BYTES = 5.megabytes

  def view_file_content
    @resource = resource_class.find(params[:id])
    authorize! :view_file_content, @resource

    max_lines = [[(params[:limit].presence || 1000).to_i, 1].max, 5000].min
    lines = []
    buffer = +""
    total_bytes = 0

    # Stream directly from storage without downloading the full file to disk.
    # throw/catch exits the streaming block early once we have enough lines
    # or the byte cap is reached (guards against newline-free files).
    catch(:preview_limit_reached) do
      @resource.file.blob.download do |chunk|
        buffer << chunk.force_encoding(Encoding::UTF_8)
        total_bytes += chunk.bytesize
        while (newline_index = buffer.index("\n"))
          lines << buffer.slice!(0..newline_index)
          throw(:preview_limit_reached) if lines.size >= max_lines
        end
        throw(:preview_limit_reached) if total_bytes >= MAX_PREVIEW_BYTES
      end
    end

    lines << buffer if lines.size < max_lines && buffer.present?

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
