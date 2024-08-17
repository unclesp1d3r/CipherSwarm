# frozen_string_literal: true

json.extract! mask_list, :id, :name, :description, :file, :line_count, :sensitive, :created_at, :updated_at
json.url mask_list_url(mask_list, format: :json)
json.file url_for(mask_list.file)
