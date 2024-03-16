require 'rails_helper'

RSpec.describe "campaigns/edit", type: :view do
  let(:campaign) {
    Campaign.create!(
      name: "MyString",
      hash_list: nil
    )
  }

  before(:each) do
    assign(:campaign, campaign)
  end

  it "renders the edit campaign form" do
    render

    assert_select "form[action=?][method=?]", campaign_path(campaign), "post" do
      assert_select "input[name=?]", "campaign[name]"

      assert_select "input[name=?]", "campaign[hash_list_id]"
    end
  end
end
