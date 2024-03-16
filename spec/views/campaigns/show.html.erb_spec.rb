require 'rails_helper'

RSpec.describe "campaigns/show", type: :view do
  before(:each) do
    assign(:campaign, Campaign.create!(
      name: "Name",
      hash_list: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(//)
  end
end
