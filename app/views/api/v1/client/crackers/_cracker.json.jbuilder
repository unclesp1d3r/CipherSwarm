# frozen_string_literal: true

json.id cracker.id
json.name cracker.name
json.binaries do
  json.array! cracker.cracker_binaries, partial: "api/v1/client/cracker_binaries/cracker_binary",
                                        as: :cracker_binary
end
