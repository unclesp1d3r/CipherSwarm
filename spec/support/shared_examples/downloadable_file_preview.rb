# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Shared examples for Downloadable#view_file_content streaming behavior.
# Usage:
#   it_behaves_like "downloadable file preview", :word_list
#
# Expects the including context to define:
#   - admin: an admin user
#   - a factory for the given resource_type
RSpec.shared_examples "downloadable file preview" do |resource_type|
  let(:view_file_content_path) { ->(resource) { send("view_file_content_#{resource_type}_path", resource) } }

  describe "file preview behavior" do
    before { sign_in admin }

    context "with default limit" do
      it "returns all lines when file is smaller than default limit" do
        resource = create(resource_type, sensitive: false, projects: [])
        get view_file_content_path.call(resource)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("turbo-stream")
      end
    end

    context "with explicit limit parameter" do
      it "honors a limit smaller than the file line count" do
        content = (1..25).map { |i| "line#{i}" }.join("\n")
        resource = create(resource_type, sensitive: false, projects: [])
        resource.file.attach(io: StringIO.new(content), filename: "test.txt")

        get view_file_content_path.call(resource), params: { limit: 5 }

        expect(response).to have_http_status(:success)
        body = response.body
        (1..5).each { |i| expect(body).to include("line#{i}") }
        expect(body).not_to include("line6")
      end

      it "clamps limit above 5000 down to 5000" do
        content = "line\n" * 10
        resource = create(resource_type, sensitive: false, projects: [])
        resource.file.attach(io: StringIO.new(content), filename: "test.txt")

        get view_file_content_path.call(resource), params: { limit: 99_999 }

        expect(response).to have_http_status(:success)
        # All 10 lines returned (clamped limit of 5000 > 10 lines)
        expect(response.body.scan("line").size).to eq(10)
      end

      it "clamps limit below 1 up to 1" do
        content = "first\nsecond\nthird\n"
        resource = create(resource_type, sensitive: false, projects: [])
        resource.file.attach(io: StringIO.new(content), filename: "test.txt")

        get view_file_content_path.call(resource), params: { limit: -5 }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("first")
        expect(response.body).not_to include("second")
      end
    end

    context "with no-newline input (byte cap)" do
      it "returns a bounded preview without crashing" do
        # Simulate a file with no newlines — buffer would grow unbounded without the byte cap
        content = "a" * 1024
        resource = create(resource_type, sensitive: false, projects: [])
        resource.file.attach(io: StringIO.new(content), filename: "no-newlines.txt")

        get view_file_content_path.call(resource)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("a" * 1024)
      end
    end

    context "with trailing content after last newline" do
      it "includes the trailing partial line" do
        content = "line1\nline2\npartial"
        resource = create(resource_type, sensitive: false, projects: [])
        resource.file.attach(io: StringIO.new(content), filename: "trailing.txt")

        get view_file_content_path.call(resource)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("partial")
      end
    end
  end
end
