# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.array! @cracker_binaries, partial: "cracker_binaries/cracker_binary", as: :cracker_binary
