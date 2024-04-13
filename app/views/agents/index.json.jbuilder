# frozen_string_literal: true

json.array! @agents, partial: "agents/agent", as: :agent
