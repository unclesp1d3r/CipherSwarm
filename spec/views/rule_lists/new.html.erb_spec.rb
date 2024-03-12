require 'rails_helper'

RSpec.describe "rule_lists/new", type: :view do
  before(:each) do
    assign(:rule_list, RuleList.new(
      name: "MyString",
      description: "MyText",
      file: nil,
      line_count: 1,
      sensitive: false
    ))
  end

  it "renders new rule_list form" do
    render

    assert_select "form[action=?][method=?]", rule_lists_path, "post" do
      assert_select "input[name=?]", "rule_list[name]"

      assert_select "textarea[name=?]", "rule_list[description]"

      assert_select "input[name=?]", "rule_list[file]"

      assert_select "input[name=?]", "rule_list[line_count]"

      assert_select "input[name=?]", "rule_list[sensitive]"
    end
  end
end
