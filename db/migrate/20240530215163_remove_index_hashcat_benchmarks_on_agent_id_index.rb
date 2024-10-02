# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RemoveIndexHashcatBenchmarksOnAgentIdIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: "index_hashcat_benchmarks_on_agent_id"
  end
end
