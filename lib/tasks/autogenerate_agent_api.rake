# frozen_string_literal: true

# This is just temporary until I can get a github action that will autogenerate the API.
namespace :autogenerate_agent_api do
  desc "Autogenerate agent API"

  swagger_file = Rails.root.join("swagger/v1/swagger.json").to_s
  generator_config = Rails.root.join(".openapi-generator.yaml").to_s
  task :go, [:output_location] => :environment do |t, args|
    exec = "openapi-generator generate -i #{swagger_file} -g go -o #{args[:output_location]} -c #{generator_config} --enable-post-process-file --git-host github.com --git-user-id unclesp1d3r --git-repo-id cipherswarm-agent-go-api"
    sh exec
  end
end
