Apipie.configure do |config|
  config.app_name = "CipherSwarm"
  config.api_base_url = "/api"
  config.doc_base_url = "/apipie"
  config.app_info = "This is the API documentation for CipherSwarm. CipherSwarm is a distributed password cracking platform that uses a client-server architecture to distribute password cracking tasks to agents."

  config.validate_presence = true
  config.validate = :implicitly
  # config.validate_key = true

  # where is your API defined?
  config.api_controllers_matcher = "#{Rails.root.join("app/controllers/**/*.rb")}"
end
