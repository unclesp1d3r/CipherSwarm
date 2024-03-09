require 'rails_helper'

RSpec.describe "crackers/index", type: :view do
  before(:each) do
    assign(:crackers, [
      Cracker.create!(
        name: "Name",
        version: "Version",
        archive_file: nil,
        active: false
      ),
      Cracker.create!(
        name: "Name",
        version: "Version",
        archive_file: nil,
        active: false
      )
    ])
  end

  it "renders a list of crackers" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Version".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
  end
end
