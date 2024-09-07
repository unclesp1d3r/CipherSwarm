# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.blank?

    # Role permissions
    # Basic users can manage any resources within their projects.
    # Admin users can manage any resources.

    can :new, [WordList, RuleList, MaskList, HashList] # User can create new lists
    can :new, Campaign # User can create new campaigns

    # Agent permissions
    can :read, Agent, user: user # User can read their own agents
    can :read, Agent, projects: { id: user.all_project_ids } # User can read agents in their projects
    can :update, Agent, user: user # User can update their own agents

    # Project permissions
    can :read, Project, project_users: { user_id: user.id } # User can read projects they are associated with

    # Campaign permissions
    can :manage, Campaign, project: { id: user.all_project_ids } # User can manage campaigns in their projects

    # Attack Resource permissions
    can %i[read view_file view_file_content], [WordList, RuleList, MaskList], sensitive: false # Public lists
    can :manage, [WordList, RuleList, MaskList], sensitive: true, projects: { id: user.all_project_ids }

    # Attack  permissions
    can :manage, Attack, campaign: { project_id: user.all_project_ids }

    # HashList permissions
    can :manage, HashList, project: { id: user.all_project_ids }

    return unless user.admin?

    can :manage, :all
    can :read, :admin_dashboard
  end
end
