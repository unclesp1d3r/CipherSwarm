require 'rails_helper'

RSpec.describe "cracker_binaries/new", type: :view do
  before(:each) do
    assign(:cracker_binary, CrackerBinary.new(
      version: "MyString",
      active: false,
      cracker: nil
    ))
  end

  it "renders new cracker_binary form" do
    render

    assert_select "form[action=?][method=?]", cracker_binaries_path, "post" do
      assert_select "input[name=?]", "cracker_binary[version]"

      assert_select "input[name=?]", "cracker_binary[active]"

      assert_select "input[name=?]", "cracker_binary[cracker_id]"
    end
  end
end
