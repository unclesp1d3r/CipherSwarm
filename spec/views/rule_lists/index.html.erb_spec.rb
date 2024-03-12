require 'rails_helper'

RSpec.describe "rule_lists/index", type: :view do
  before(:each) do
    assign(:rule_lists, [
      RuleList.create!(
        name: "Name",
        description: "MyText",
        file: nil,
        line_count: 2,
        sensitive: false
      ),
      RuleList.create!(
        name: "Name",
        description: "MyText",
        file: nil,
        line_count: 2,
        sensitive: false
      )
    ])
  end

  it "renders a list of rule_lists" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(2.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
  end
end
