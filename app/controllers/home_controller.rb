# frozen_string_literal: true

class HomeController < ApplicationController
  # Renders the home page.
  def index; end

  def toggle_hide_completed_activities
    authorize! :read, current_user
    current_user.toggle_hide_completed_activities
    render partial: "campaigns/hide_completed_activities_toggle"
  end
end
