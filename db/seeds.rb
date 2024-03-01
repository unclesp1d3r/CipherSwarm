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

unless Project.exists?(name: "Default Project")
  project = Project.new
  project.name = "Default Project"
  project.description = "This is the default project."
  project.users.append(User.first)
  project.save!
end
