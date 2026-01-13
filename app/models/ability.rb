# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
# The Ability class defines the authorization rules for different user roles
# using the CanCanCan gem. It specifies what actions a user can perform on
# various resources based on their role and associations.
#
# Permissions:
# - Basic users can manage resources within their projects.
# - Admin users can manage any resources.
#
# Specific Permissions:
# - Users can create new WordList, RuleList, MaskList, HashList, and Campaign.
# - Users can read and update their own agents and read agents in their projects.
# - Users can read projects they are associated with.
# - Users can manage campaigns in their projects.
# - Users can read public WordList, RuleList, and MaskList.
# - Users can manage sensitive WordList, RuleList, and MaskList in their projects.
# - Users can manage attacks in campaigns within their projects.
# - Users can manage HashList in their projects.
#
# Admin Permissions:
# - Admin users can manage all resources and read the admin dashboard.
class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.blank?

    # Role permissions
    # Basic users can manage any resources within their projects.
    # Admin users can manage any resources.

    can :read, User, id: user.id # User can read their own profile

    can :new, [WordList, RuleList, MaskList, HashList] # User can create new lists
    can :create, Campaign # User can create new campaigns

    # Agent permissions
    can :create, Agent # User can create agents
    can :read, Agent, user: user # User can read their own agents
    can :read, Agent, projects: { id: user.all_project_ids } # User can read agents in their projects
    can :update, Agent, user: user # User can update their own agents
    can :destroy, Agent, user: user # User can destroy their own agents

    # Project permissions
    can :read, Project, project_users: { user_id: user.id } # User can read projects they are associated with

    # Campaign permissions
    can :manage, Campaign, project: { id: user.all_project_ids } # User can manage campaigns in their projects
    cannot :set_high_priority, Campaign # By default, users cannot set high priority

    # High priority campaign permissions - only project admins/owners and global admins can set high priority
    can :set_high_priority, Campaign do |campaign|
      user.admin? || user.project_users.exists?(
        project_id: campaign.project_id,
        role: %i[admin owner]
      )
    end

    # Attack Resource permissions
    can %i[read create view_file view_file_content], [WordList, RuleList, MaskList], sensitive: false # Public lists
    can :manage, [WordList, RuleList, MaskList], projects: { id: user.all_project_ids }
    can %i[read create update destroy view_file view_file_content], [WordList, RuleList, MaskList], creator: user

    # Attack  permissions
    can :manage, Attack, campaign: { project_id: user.all_project_ids }
    can :manage, Task, campaign: { attack: { project_id: user.all_project_ids } }

    # HashList permissions
    can :manage, HashList, project: { id: user.all_project_ids }

    return unless user.admin?

    can :manage, :all
    can :read, :admin_dashboard
  end
end
