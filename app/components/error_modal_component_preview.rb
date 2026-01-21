# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ErrorModalComponentPreview < ApplicationViewComponentPreview
  def info_error
    render(ErrorModalComponent.new(error: build_error(severity: :info), modal_id: "error-info"))
  end

  def warning_error
    render(ErrorModalComponent.new(error: build_error(severity: :warning), modal_id: "error-warning"))
  end

  def critical_error
    render(ErrorModalComponent.new(error: build_error(severity: :critical, task_id: 42), modal_id: "error-critical"))
  end

  def fatal_error
    render(ErrorModalComponent.new(error: build_error(severity: :fatal, metadata: { context: "kernel" }),
                                   modal_id: "error-fatal"))
  end

  private

  def build_error(severity:, task_id: nil, metadata: { code: "E123" })
    AgentError.new(
      message: "Something went wrong",
      severity: severity,
      metadata: metadata,
      created_at: Time.current,
      task_id: task_id,
      agent_id: 1
    )
  end
end
