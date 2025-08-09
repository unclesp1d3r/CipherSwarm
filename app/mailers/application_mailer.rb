# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end
