# frozen_string_literal: true

# A name factory that generates a unique name for each instance
# This should reduce the number of failed tests due to unique constraints
FactoryBot.define do
  sequence(:name) { "#{Faker::Lorem.words(number: 3)} #{_1}" }
end
