# frozen_string_literal: true

json.array! @cracker_binaries, partial: "cracker_binaries/cracker_binary", as: :cracker_binary
