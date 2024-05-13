# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # TODO: Add more granular permissions for users and agents.

  def initialize(user)
    return if user.blank?
    project_ids = user.projects.pluck(:id)

    can :create, []

    # Agent permissions
    can :read, Agent, user_id: user.id # Agents associated with the user
    can :read, Agent, projects: { id: project_ids } # Agents associated with the user's projects
    can :edit, Agent, user_id: user.id # Agents associated with the user

    # Project permissions
    can :read, Project, id: project_ids # Projects that belong to the user
    can :edit, Project, project_users: { user_id: user.id, admin?: true }
    can :edit, Project, project_users: { user_id: user.id, editor?: true }
    can :edit, Project, project_users: { user_id: user.id, contributor?: true }
    can :edit, Project, project_users: { user_id: user.id, owner?: true }
    can :destroy, Project, project_users: { user_id: user.id, owner?: true }

    # Campaign permissions
    can :read, Campaign, project_id: project_ids # Campaigns that belong to the user's projects
    can :edit, Campaign, project_id: project_ids # Campaigns that belong to the user's projects
    can :create, Campaign # Everyone can create campaigns

    # Wordlist permissions
    can :read, WordList, sensitive: false, processed: true # Public wordlists
    can :read, WordList, projects: { id: project_ids }, processed: true # Wordlists that belong to the user's projects
    can :edit, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects
    can :create, WordList # Everyone can create wordlists
    can :destroy, WordList, projects: { id: project_ids } # Wordlists that belong to the user's projects

    # Attack permissions
    can :read, Attack, campaign: { project_id: project_ids } # Attacks that belong to the user's projects
    can :edit, Attack, campaign: { project_id: project_ids } # Attacks that belong to the user's projects
    can :create, Attack # Everyone can create attacks

    return unless user.admin?

    can :manage, :all
    can :read, :admin_dashboard
  end
end
