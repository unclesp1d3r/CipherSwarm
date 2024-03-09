json.extract! cracker, :id, :name, :version, :archive_file, :active, :created_at, :updated_at
json.url cracker_url(cracker, format: :json)
json.archive_file url_for(cracker.archive_file)
