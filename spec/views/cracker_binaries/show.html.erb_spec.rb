require 'rails_helper'

RSpec.describe "cracker_binaries/show", type: :view do
  before(:each) do
    assign(:cracker_binary, CrackerBinary.create!(
      version: "Version",
      active: false,
      cracker: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Version/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(//)
  end
end
