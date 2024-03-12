json.extract! word_list, :id, :name, :description, :file, :line_count, :sensitive, :created_at, :updated_at
json.url word_list_url(word_list, format: :json)
json.file url_for(word_list.file)
