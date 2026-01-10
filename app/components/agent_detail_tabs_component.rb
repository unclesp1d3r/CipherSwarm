# frozen_string_literal: true

class AgentDetailTabsComponent < ApplicationViewComponent
  option :agent, required: true
  option :errors, required: true
  option :pagy, required: true

  renders_one :overview_tab
  renders_one :errors_tab
  renders_one :configuration_tab
  renders_one :capabilities_tab

  def tab_id(name)
    "#{helpers.dom_id(agent)}_#{name}_tab"
  end

  def panel_id(name)
    "#{helpers.dom_id(agent)}_#{name}_panel"
  end
end
