# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe TaskActionsComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:attack) { create(:dictionary_attack) }
  let(:agent) { create(:agent) }
  let(:task) { create(:task, attack: attack, agent: agent) }

  describe "with full permissions" do
    let(:ability) do
      ability = Ability.new(nil)
      ability.can :manage, Task
      ability
    end

    context "when task is pending" do
      before { task.update!(state: "pending") }

      it "renders cancel button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_button("Cancel")
        expect(page).to have_css("form[action='#{cancel_task_path(task)}']")
      end

      it "renders reassign form when compatible agents exist" do
        # Create a compatible agent (no project restrictions)
        create(:agent)
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_button("Reassign")
      end

      it "shows no compatible agents message when none available" do
        # All agents are incompatible (different projects)
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_content("No compatible agents available")
      end

      it "does not render retry button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Retry")
      end

      it "renders logs link" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_link("Logs", href: logs_task_path(task))
      end

      it "renders download results link" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_link("Download Results", href: download_results_task_path(task))
      end
    end

    context "when task is running" do
      before { task.update!(state: "running") }

      it "renders cancel button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_button("Cancel")
      end

      it "does not render retry button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Retry")
      end

      it "does not render reassign button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Reassign")
      end
    end

    context "when task is failed" do
      before { task.update!(state: "failed") }

      it "renders retry button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_button("Retry")
        expect(page).to have_css("form[action='#{retry_task_path(task)}']")
      end

      it "renders reassign form when compatible agents exist" do
        # Create a compatible agent (no project restrictions)
        create(:agent)
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_button("Reassign")
      end

      it "does not render cancel button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Cancel")
      end
    end

    context "when task is completed" do
      before { task.update!(state: "completed") }

      it "does not render cancel button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Cancel")
      end

      it "does not render retry button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Retry")
      end

      it "does not render reassign button" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Reassign")
      end

      it "still renders logs link" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_link("Logs")
      end

      it "still renders download results link" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_link("Download Results")
      end
    end
  end

  describe "with limited permissions" do
    let(:ability) do
      ability = Ability.new(nil)
      ability.can :read, Task
      ability
    end

    context "when task is pending" do
      before { task.update!(state: "pending") }

      it "does not render cancel button without permission" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Cancel")
      end

      it "does not render reassign button without permission" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_button("Reassign")
      end

      it "renders logs link (always visible)" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_link("Logs")
      end

      it "does not render download results without permission" do
        render_inline(described_class.new(task: task, current_ability: ability))

        expect(page).to have_no_link("Download Results")
      end
    end
  end

  describe "#can_cancel?" do
    let(:ability) do
      ability = Ability.new(nil)
      ability.can :cancel, Task
      ability
    end

    it "returns true when pending and has permission" do
      task.update!(state: "pending")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_cancel?).to be true
    end

    it "returns true when running and has permission" do
      task.update!(state: "running")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_cancel?).to be true
    end

    it "returns false when completed" do
      task.update!(state: "completed")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_cancel?).to be false
    end
  end

  describe "#can_retry?" do
    let(:ability) do
      ability = Ability.new(nil)
      ability.can :retry, Task
      ability
    end

    it "returns true when failed and has permission" do
      task.update!(state: "failed")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_retry?).to be true
    end

    it "returns false when running" do
      task.update!(state: "running")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_retry?).to be false
    end
  end

  describe "#can_reassign?" do
    let(:ability) do
      ability = Ability.new(nil)
      ability.can :reassign, Task
      ability
    end

    it "returns true when pending and has permission" do
      task.update!(state: "pending")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_reassign?).to be true
    end

    it "returns true when failed and has permission" do
      task.update!(state: "failed")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_reassign?).to be true
    end

    it "returns true when running and has permission" do
      task.update!(state: "running")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_reassign?).to be true
    end

    it "returns true when paused and has permission" do
      task.update!(state: "paused")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_reassign?).to be true
    end

    it "returns false when completed" do
      task.update!(state: "completed")
      component = described_class.new(task: task, current_ability: ability)

      expect(component.can_reassign?).to be false
    end
  end
end
