require 'rails_helper'

RSpec.describe "campaigns/new", type: :view do
  before(:each) do
    assign(:campaign, Campaign.new(
      name: "MyString",
      hash_list: nil
    ))
  end

  it "renders new campaign form" do
    render

    assert_select "form[action=?][method=?]", campaigns_path, "post" do
      assert_select "input[name=?]", "campaign[name]"

      assert_select "input[name=?]", "campaign[hash_list_id]"
    end
  end
end
