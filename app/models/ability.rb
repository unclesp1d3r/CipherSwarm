# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # TODO: Add more granular permissions for users and agents.

  def initialize(user)
    return if user.blank?

    can :create, []

    # Agent permissions
    can :read, Agent, user_id: user.id # Agents associated with the user's projects
    can :read, Agent, projects: { id: user.project_ids } # Agents associated with the user's projects
    can :edit, Agent, user_id: user.id # Agents associated with the user

    # Project permissions
    can :read, Project, id: user.project_ids # Projects that belong to the user
    can :edit, Project, project_users: { user_id: user.id, admin?: true }
    can :edit, Project, project_users: { user_id: user.id, editor?: true }
    can :edit, Project, project_users: { user_id: user.id, contributor?: true }
    can :edit, Project, project_users: { user_id: user.id, owner?: true }
    can :destroy, Project, project_users: { user_id: user.id, owner?: true }

    return unless user.admin?
    can :manage, :all
    can :read, :admin_dashboard
  end
end
