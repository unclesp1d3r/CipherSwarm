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
    @resource = controller_path.classify.constantize.find(params[:id])
    authorize! :read, @resource

    redirect_to rails_blob_url @resource.file
  end

  def view_file
    @resource = controller_path.classify.constantize.find(params[:id])

    render "shared/attack_resource/view_file"
  end

  def view_file_content
    @resource = controller_path.classify.constantize.find(params[:id])

    max_lines = params[:limit] ||= 1000
    @resource.file.blob.open do |file|
      @file_content = file.read
    end
    if @file_content.lines.count > max_lines
      @file_content = @file_content.lines.first(max_lines).join
    end
    render turbo_stream: turbo_stream.replace(:file_content,
                                              partial: "shared/attack_resource/file_content",
                                              locals: { file_content: @file_content })
  end
end
