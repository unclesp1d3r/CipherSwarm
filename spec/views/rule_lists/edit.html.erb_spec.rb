require 'rails_helper'

RSpec.describe "rule_lists/edit", type: :view do
  let(:rule_list) {
    RuleList.create!(
      name: "MyString",
      description: "MyText",
      file: nil,
      line_count: 1,
      sensitive: false
    )
  }

  before(:each) do
    assign(:rule_list, rule_list)
  end

  it "renders the edit rule_list form" do
    render

    assert_select "form[action=?][method=?]", rule_list_path(rule_list), "post" do
      assert_select "input[name=?]", "rule_list[name]"

      assert_select "textarea[name=?]", "rule_list[description]"

      assert_select "input[name=?]", "rule_list[file]"

      assert_select "input[name=?]", "rule_list[line_count]"

      assert_select "input[name=?]", "rule_list[sensitive]"
    end
  end
end
