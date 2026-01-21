# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# rubocop:disable Rails/SkipsModelValidations -- Intentionally bypassing validations to set specific states for test data
namespace :dev do
  desc "Generate comprehensive test data using FactoryBot for development"
  task seed: :environment do
    require "factory_bot_rails"

    # Only load factories if they haven't been loaded yet
    unless FactoryBot.factories.any?
      puts "Loading FactoryBot factories..."
      FactoryBot.find_definitions
    end

    puts "Creating test data..."

    # Ensure we have base data from seeds
    project = Project.first
    unless project
      puts "ERROR: No project found. Please run `rails db:seed` first."
      exit 1
    end

    agent = Agent.first
    unless agent
      puts "ERROR: No agent found. Please run `rails db:seed` first."
      exit 1
    end

    puts "Using project: #{project.name}"
    puts "Using agent: #{agent.host_name}"

    # Create multiple campaigns with different priorities
    campaigns_data = [
      { name: "Password Recovery - Corp Users", priority: :routine },
      { name: "Breach Analysis - Q4 Dataset", priority: :priority },
      { name: "Security Audit - Internal", priority: :urgent },
      { name: "Research - Hash Algorithm Study", priority: :deferred }
    ]

    campaigns_data.each_with_index do |data, index|
      puts "\nCreating campaign #{index + 1}: #{data[:name]}"

      # Create a hash list for this campaign
      hash_list = FactoryBot.create(:hash_list, name: "#{data[:name]} - Hashes")
      puts "  Created hash list: #{hash_list.name}"

      # Add hash items to the list
      10.times do |i|
        hash_value = Digest::MD5.hexdigest("password#{index}#{i}")
        hash_item = HashItem.create!(
          hash_value: hash_value,
          hash_list: hash_list
        )
        # Mark some as cracked
        if i < 3
          hash_item.update!(
            plain_text: "password#{index}#{i}",
            cracked: true,
            cracked_time: Time.current - rand(1..72).hours
          )
        end
      end
      puts "  Created #{hash_list.hash_items.count} hash items (#{hash_list.hash_items.where(cracked: true).count} cracked)"

      # Create campaign
      campaign = Campaign.create!(
        name: data[:name],
        hash_list: hash_list,
        project: project,
        priority: data[:priority],
        description: "Test campaign for development - #{data[:priority]} priority"
      )
      puts "  Created campaign: #{campaign.name} (#{campaign.priority})"

      # Create various attacks for each campaign
      attacks_config = [
        { type: :dictionary_attack, state: index.zero? ? "running" : "pending" },
        { type: :mask_attack, state: index.zero? ? "completed" : "pending" },
        { type: :dictionary_attack, state: index == 1 ? "failed" : "pending" }
      ]

      attacks_config.each_with_index do |attack_config, attack_index|
        attack = FactoryBot.create(
          attack_config[:type],
          campaign: campaign,
          name: "Attack #{attack_index + 1} - #{attack_config[:type].to_s.humanize}"
        )
        puts "    Created attack: #{attack.name}"

        # Transition to correct state
        case attack_config[:state]
        when "running"
          attack.run! if attack.can_run?
          # Create a running task
          task = FactoryBot.create(:task, attack: attack, agent: agent)
          task.update_column(:state, "running")
          puts "      Created running task"
        when "completed"
          attack.run! if attack.can_run?
          # Mark tasks as completed first
          attack.tasks.each { |t| t.update_column(:state, "completed") }
          attack.update_column(:state, "completed")
          puts "      Marked as completed"
        when "failed"
          attack.run! if attack.can_run?
          attack.error! if attack.can_error?
          # Create an error for failed attacks
          task = FactoryBot.create(:task, attack: attack, agent: agent)
          task.update_column(:state, "paused")
          FactoryBot.create(
            :agent_error,
            agent: agent,
            task: task,
            message: "GPU memory exhausted during attack execution",
            severity: :critical
          )
          puts "      Marked as failed with error"
        end
      end
    end

    # Create some additional agent errors for the error log
    puts "\nCreating additional agent errors..."
    severities = %i[info warning minor major critical fatal]
    5.times do |i|
      task = Task.order("RANDOM()").first
      FactoryBot.create(
        :agent_error,
        agent: agent,
        task: task,
        message: "Sample error #{i + 1}: #{Faker::Lorem.sentence}",
        severity: severities.sample,
        created_at: Time.current - rand(1..168).hours
      )
    end
    puts "Created #{AgentError.count} total agent errors"

    puts "\n" + "=" * 60
    puts "Test data generation complete!"
    puts "=" * 60
    puts "\nSummary:"
    puts "  Campaigns: #{Campaign.count}"
    puts "  Hash Lists: #{HashList.count}"
    puts "  Hash Items: #{HashItem.count} (#{HashItem.where(cracked: true).count} cracked)"
    puts "  Attacks: #{Attack.count}"
    puts "  Tasks: #{Task.count}"
    puts "  Agent Errors: #{AgentError.count}"
    puts "\nYou can view campaigns at: /campaigns"
  end

  desc "Clear all dev test data (except seeds)"
  task clear: :environment do
    puts "Clearing test data..."

    # Delete in reverse dependency order
    AgentError.delete_all
    Task.delete_all
    Attack.delete_all
    Campaign.delete_all
    HashItem.delete_all
    HashList.delete_all
    WordList.delete_all

    puts "Test data cleared!"
    puts "Note: Seeds (users, project, agent, hash types) are preserved."
  end

  desc "Reset and regenerate all dev test data"
  task reset: %i[clear seed] do
    puts "Dev data reset complete!"
  end
end
# rubocop:enable Rails/SkipsModelValidations
