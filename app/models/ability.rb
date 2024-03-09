# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # TODO: Add more granular permissions for users and agents.

  def initialize(user)
    return unless user.present?

    can :read, :all
    can :create, [ Agent, Project, Cracker, OperatingSystem ]
    can :update, [ Agent, Project, Cracker, OperatingSystem ], user_id: user.id
    can :destroy, [ Agent, Project, Cracker, OperatingSystem ], user_id: user.id
    can :read, Agent, project_ids: user.project_ids # Agents associated with the user's projects
    can :read, Project, id: user.project_ids # Projects that belong to the user
    can :read, Agent, user_id: user.id # Agents that belong to the user

    # TODO: Need to implement project roles and permissions.

    return unless user.admin?
    can :manage, :all
    can :read, :admin_dashboard
  end
end
