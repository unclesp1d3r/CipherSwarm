require 'rails_helper'

RSpec.describe "hash_lists/show", type: :view do
  before(:each) do
    assign(:hash_list, HashList.create!(
      name: "Name",
      description: "MyText",
      file: nil,
      line_count: 2,
      sensitive: false,
      hash_mode: 3
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(//)
    expect(rendered).to match(/2/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/3/)
  end
end
