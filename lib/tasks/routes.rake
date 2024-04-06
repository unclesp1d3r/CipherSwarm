# frozen_string_literal: true

task routes: :environment do
  puts `bundle exec rails routes`
end
