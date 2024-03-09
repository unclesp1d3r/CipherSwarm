require 'rails_helper'

RSpec.describe "crackers/show", type: :view do
  before(:each) do
    assign(:cracker, Cracker.create!(
      name: "Name",
      version: "Version",
      archive_file: nil,
      active: false
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Version/)
    expect(rendered).to match(//)
    expect(rendered).to match(/false/)
  end
end
