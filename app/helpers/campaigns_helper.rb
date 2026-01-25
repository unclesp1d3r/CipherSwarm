# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Helper methods for Campaign views
module CampaignsHelper
  # Returns available priorities for a campaign based on user permissions.
  #
  # Priority levels and access control:
  # - deferred, normal: Available to all users
  # - high: Restricted to project admins/owners and global admins
  #
  # This restriction prevents resource starvation by limiting who can
  # create high-priority campaigns that preempt lower-priority work.
  #
  # @param campaign [Campaign] the campaign being edited/created
  # @param user [User] the current user
  ##
  # Determine which priority options are available to a given user for a campaign.
  # @param [Campaign] campaign - The campaign being edited or created; used to infer the associated project when present.
  # @param [User] user - The current user whose permissions determine available priorities.
  # @return [Array<Symbol>] The available priority symbols. Always includes `:deferred` and `:normal`; includes `:high` when the user is a global admin or an admin/owner of the campaign's project.
  def available_priorities_for(campaign, user)
    base_priorities = %i[deferred normal]

    # Global admins can set any priority
    return base_priorities + [:high] if user.admin?

    # Check if user is project admin/owner for the campaign's project
    project_id = campaign.project_id || campaign.hash_list&.project_id
    return base_priorities unless project_id

    is_project_admin = user.project_users.exists?(
      project_id: project_id,
      role: %i[admin owner]
    )

    is_project_admin ? base_priorities + [:high] : base_priorities
  end
end
