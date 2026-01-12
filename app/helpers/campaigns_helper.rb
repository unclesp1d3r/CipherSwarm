# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Helper methods for Campaign views
module CampaignsHelper
  # Returns available priorities for a campaign based on user permissions
  #
  # @param campaign [Campaign] the campaign being edited/created
  # @param user [User] the current user
  # @return [Array<Symbol>] available priority options
  def available_priorities_for(campaign, user)
    base_priorities = %i[deferred normal]

    # Global admins can set any priority
    return base_priorities + [:high] if user.admin?

    # Check if user is project admin/owner
    project_id = campaign.project_id || campaign.hash_list&.project_id
    return base_priorities unless project_id

    is_project_admin = user.projects.joins(:project_users).exists?(
      project_users: { project_id: project_id, role: %i[admin owner] }
    )

    is_project_admin ? base_priorities + [:high] : base_priorities
  end
end
