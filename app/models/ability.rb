# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # TODO: Add more granular permissions for users and agents.

  def initialize(user)
    return if user.blank?
    project_ids = user.projects.pluck(:id)

    can :create, [Project, Campaign, Agent, WordList, RuleList, MaskList, Attack, HashList]

    # Agent permissions
    can :read, Agent, user_id: user.id # Agents associated with the user
    can :read, Agent, projects: { id: project_ids } # Agents associated with the user's projects
    can :update, Agent, user_id: user.id # Agents associated with the user

    # Project permissions
    can :read, Project, id: project_ids # Projects that belong to the user
    can :update, Project, project_users: { user_id: user.id, admin?: true }
    can :update, Project, project_users: { user_id: user.id, editor?: true }
    can :update, Project, project_users: { user_id: user.id, contributor?: true }
    can :update, Project, project_users: { user_id: user.id, owner?: true }

    # Campaign permissions
    can :read, Campaign, project_id: project_ids # Campaigns that belong to the user's projects
    can :update, Campaign, project_id: project_ids # Campaigns that belong to the user's projects

    # Wordlist permissions
    can :read, WordList, sensitive: false # Public wordlists
    can :read, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects
    can :update, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects
    can :destroy, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects
    can :view_file, WordList, sensitive: false
    can :view_file, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects
    can :view_file_content, WordList, sensitive: false
    can :view_file_content, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects

    # RuleList permissions
    can :read, RuleList, sensitive: false # Public Rule lists
    can :read, RuleList, projects: { id: project_ids } # Rule lists that belong to the user's projects
    can :update, RuleList, projects: { id: project_ids } # Rule lists that belong to the user's projects
    can :destroy, RuleList, projects: { id: project_ids } # Rule lists that belong to the user's projects
    can :view_file, RuleList, sensitive: false
    can :view_file, RuleList, projects: { id: project_ids } # Rule lists that belong to the user's projects
    can :view_file_content, RuleList, sensitive: false
    can :view_file_content, RuleList, projects: { id: project_ids } # Rule lists that belong to the user's projects

    # MaskList permissions
    can :read, MaskList, sensitive: false # Public Mask lists
    can :read, MaskList, projects: { id: project_ids } # Mask lists that belong to the user's projects
    can :update, MaskList, projects: { id: project_ids } # Mask lists that belong to the user's projects
    can :destroy, MaskList, projects: { id: project_ids } # Rule lists that belong to the user's projects
    can :view_file, MaskList, sensitive: false
    can :view_file, MaskList, projects: { id: project_ids } # Mask lists that belong to the user's projects
    can :view_file_content, MaskList, sensitive: false
    can :view_file_content, MaskList, projects: { id: project_ids } # Mask lists that belong to the user's projects

    # Attack permissions
    can :read, Attack, campaign: { project_id: project_ids } # Attacks that belong to the user's projects
    can :update, Attack, campaign: { project_id: project_ids } # Attacks that belong to the user's projects
    can :destroy, Attack, campaign: { project_id: project_ids } # Attacks that belong to the user's projects

    # HashList permissions
    can :read, HashList, project: { id: project_ids } # HashLists that belong to the user's projects
    can :update, HashList, project: { id: project_ids } # HashLists that belong to the user's projects
    can :destroy, HashList, project: { id: project_ids } # HashLists that belong to the user's projects

    return unless user.admin?

    can :manage, :all
    can :read, :admin_dashboard
  end
end
