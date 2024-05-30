# frozen_string_literal: true

class RemoveIndexHashcatBenchmarksOnAgentIdIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: 'index_hashcat_benchmarks_on_agent_id'
  end
end
