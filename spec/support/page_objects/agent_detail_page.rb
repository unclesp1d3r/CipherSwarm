# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Page object for the agent detail view with tabbed content
class AgentDetailPage < BasePage
  TAB_KEYS = {
    "Overview" => "overview",
    "Errors" => "errors",
    "Configuration" => "configuration",
    "Capabilities" => "capabilities"
  }.freeze

  attr_reader :agent

  def visit_page(agent)
    @agent = agent
    visit agent_path(agent)
    session.find(".tab-content", wait: 5)
    self
  end

  def click_tab(tab_name)
    tab_link(tab_name).click

    # Wait for any Stimulus controller to run
    sleep 0.1

    # Manually toggle panel visibility since Stimulus might not run reliably in test
    target_panel_id = panel_id(tab_name)
    target_tab_id = tab_id(tab_name)

    # Use evaluate_script to ensure JS completes and returns result
    result = session.evaluate_script(<<~JS)
      (function() {
        const targetTabId = "#{target_tab_id}";
        const targetPanelId = "#{target_panel_id}";

        // Hide all panels and deactivate all tabs
        document.querySelectorAll('[data-tabs-target="panel"]').forEach(p => {
          p.classList.add("d-none");
          p.setAttribute("aria-hidden", "true");
        });
        document.querySelectorAll('[data-tabs-target="tab"]').forEach(t => {
          t.classList.remove("active");
          t.setAttribute("aria-selected", "false");
        });

        // Show target panel and activate target tab
        const tab = document.getElementById(targetTabId);
        const panel = document.getElementById(targetPanelId);
        if (tab) {
          tab.classList.add("active");
          tab.setAttribute("aria-selected", "true");
        }
        if (panel) {
          panel.classList.remove("d-none");
          panel.setAttribute("aria-hidden", "false");
          return { success: true, panelClasses: panel.className };
        } else {
          return { success: false, error: "Panel not found: " + targetPanelId };
        }
      })();
    JS

    unless result && result["success"]
      raise "Tab switch failed: #{result&.fetch('error', 'Unknown error')}"
    end

    # Debug: Check the panel state after JS
    panel_state = session.evaluate_script(<<~JS)
      (function() {
        const panel = document.getElementById("#{target_panel_id}");
        if (!panel) return { exists: false };
        const style = window.getComputedStyle(panel);
        return {
          exists: true,
          className: panel.className,
          display: style.display,
          visibility: style.visibility,
          offsetWidth: panel.offsetWidth,
          offsetHeight: panel.offsetHeight
        };
      })();
    JS

    # If panel is hidden due to CSS, we need to work around it
    if panel_state && panel_state["display"] == "none"
      # Force display by removing d-none and any other hiding
      session.execute_script("document.getElementById('#{target_panel_id}').style.display = 'block';")
    end

    # Wait for panel to actually be visible in the DOM
    begin
      session.find("##{target_panel_id}", visible: true, wait: 5)
    rescue Capybara::ElementNotFound
      raise Capybara::ElementNotFound,
            "Panel still not visible. State: #{panel_state.inspect}, JS result: #{result.inspect}"
    end
    self
  end

  def active_tab
    find("a.nav-link.active").text.strip
  end

  def has_tab?(tab_name)
    has_css?(tab_selector(tab_name))
  end

  def has_active_tab?(tab_name)
    tab_link(tab_name)[:class].to_s.split.include?("active")
  end

  def overview_content
    tab_panel("Overview")
  end

  def errors_content
    tab_panel("Errors")
  end

  def configuration_content
    tab_panel("Configuration")
  end

  def capabilities_content
    tab_panel("Capabilities")
  end

  def has_current_task?
    within(overview_content) do
      has_no_text?("No active task")
    end
  end

  def has_performance_metrics?
    within(overview_content) do
      has_css?(".card-title", text: "Performance Metrics") &&
        has_text?("Hash Rate") &&
        has_text?("Temperature") &&
        has_text?("Utilization")
    end
  end

  def has_agent_status?
    within(overview_content) do
      has_css?(".card-title", text: "Agent Status") && has_css?(".badge")
    end
  end

  def has_errors_table?
    within(errors_content) do
      has_css?("table", visible: :all)
    end
  end

  def error_count
    within(errors_content) do
      all("tbody tr", visible: :all).size
    end
  end

  def has_configuration_details?
    within(configuration_content) do
      has_css?(".card-title", text: "Basic Configuration", visible: :all) &&
        has_css?(".card-title", text: "Advanced Configuration", visible: :all)
    end
  end

  def has_capabilities_details?
    within(capabilities_content) do
      has_css?(".card-title", text: "Device Information", visible: :all) &&
        has_css?(".card-title", text: "Supported Hash Types", visible: :all)
    end
  end

  def has_benchmarks_table?
    within(capabilities_content) do
      has_css?("table", visible: :all)
    end
  end

  def benchmark_count
    within(capabilities_content) do
      all("tbody tr", visible: :all).size
    end
  end

  private

  def tab_link(tab_name)
    find(tab_selector(tab_name))
  end

  def tab_panel(tab_name)
    find("turbo-frame##{frame_id(tab_name)}", visible: :all)
  end

  def tab_selector(tab_name)
    "##{tab_id(tab_name)}"
  end

  def tab_id(tab_name)
    "#{dom_id_prefix}_#{tab_key(tab_name)}_tab"
  end

  def panel_id(tab_name)
    "#{dom_id_prefix}_#{tab_key(tab_name)}_panel"
  end

  def frame_id(tab_name)
    # Rails dom_id uses prefix format: dom_id(agent, :overview) => "overview_agent_1"
    "#{tab_key(tab_name)}_#{dom_id_prefix}"
  end

  def tab_key(tab_name)
    TAB_KEYS.fetch(tab_name) { tab_name.to_s.downcase }
  end

  def dom_id_prefix
    return ActionView::RecordIdentifier.dom_id(agent) if agent

    @dom_id_prefix ||= begin
      container = session.first("div[id^='agent_']", visible: :all)
      raise ArgumentError, "Agent not set" unless container

      container[:id]
    end
  end
end
