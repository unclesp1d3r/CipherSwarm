RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run show_in_doc: true if ENV['APIPIE_RECORD']
end
