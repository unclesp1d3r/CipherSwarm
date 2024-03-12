require 'rails_helper'

RSpec.describe "rule_lists/show", type: :view do
  before(:each) do
    assign(:rule_list, RuleList.create!(
      name: "Name",
      description: "MyText",
      file: nil,
      line_count: 2,
      sensitive: false
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(//)
    expect(rendered).to match(/2/)
    expect(rendered).to match(/false/)
  end
end
