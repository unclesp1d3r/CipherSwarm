require 'rails_helper'

RSpec.describe "cracker_binaries/edit", type: :view do
  let(:cracker_binary) {
    CrackerBinary.create!(
      version: "MyString",
      active: false,
      cracker: nil
    )
  }

  before(:each) do
    assign(:cracker_binary, cracker_binary)
  end

  it "renders the edit cracker_binary form" do
    render

    assert_select "form[action=?][method=?]", cracker_binary_path(cracker_binary), "post" do

      assert_select "input[name=?]", "cracker_binary[version]"

      assert_select "input[name=?]", "cracker_binary[active]"

      assert_select "input[name=?]", "cracker_binary[cracker_id]"
    end
  end
end
