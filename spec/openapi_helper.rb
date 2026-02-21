# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# rswag 3.x loads openapi_helper by default; this shim delegates to swagger_helper
# to maintain backward compatibility with existing specs and CI scripts.
require "swagger_helper"
