require 'rails_helper'

RSpec.describe "hash_lists/index", type: :view do
  before(:each) do
    assign(:hash_lists, [
      HashList.create!(
        name: "Name",
        description: "MyText",
        file: nil,
        line_count: 2,
        sensitive: false,
        hash_mode: 3
      ),
      HashList.create!(
        name: "Name",
        description: "MyText",
        file: nil,
        line_count: 2,
        sensitive: false,
        hash_mode: 3
      )
    ])
  end

  it "renders a list of hash_lists" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(2.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(3.to_s), count: 2
  end
end
