# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
unless User.exists?(name: "admin")
  user = User.new
  user.name = "admin"
  user.email = "admin@example.com"
  user.password = "password"
  user.password_confirmation = "password"
  user.role = :admin
  user.save!
end

unless User.exists?(name: "user")
  user = User.new
  user.name = "user"
  user.email = "nobody@example.com"
  user.password = "password"
  user.password_confirmation = "password"
  user.role = :basic
end

unless Project.exists?(name: "Default Project")
  project = Project.new
  project.name = "Default Project"
  project.description = "This is the default project."
  project.users.append(User.first)
  project.save!
end

OperatingSystem.create(name: "windows", cracker_command: "hashcat.exe") unless OperatingSystem.exists?(name: "windows")
OperatingSystem.create(name: "linux", cracker_command: "hashcat.bin") unless OperatingSystem.exists?(name: "linux")
OperatingSystem.create(name: "darwin", cracker_command: "hashcat.bin") unless OperatingSystem.exists?(name: "darwin")

if Rails.env.local? && !Agent.count.positive?
  agent = Agent.new
  agent.name = "Agent 1"
  agent.user = User.first
  agent.projects.append(Project.first)
  agent.advanced_configuration = { use_native_hashcat: true }
  agent.save!
end

require 'csv'
csv_text = Rails.root.join("lib/seeds/hash_types.csv").read
csv = CSV.parse(csv_text, headers: true)
csv.each do |row|
  HashType.create!(row.to_h) unless HashType.exists?(hashcat_mode: row['hashcat_mode'])
end
