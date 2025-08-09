# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.id cracker.id
json.name cracker.name
json.binaries do
  json.array! cracker.cracker_binaries, partial: "api/v1/client/cracker_binaries/cracker_binary",
                                        as: :cracker_binary
end
