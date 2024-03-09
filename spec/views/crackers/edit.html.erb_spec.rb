require 'rails_helper'

RSpec.describe "crackers/edit", type: :view do
  let(:cracker) {
    Cracker.create!(
      name: "MyString",
      version: "MyString",
      archive_file: nil,
      active: false
    )
  }

  before(:each) do
    assign(:cracker, cracker)
  end

  it "renders the edit cracker form" do
    render

    assert_select "form[action=?][method=?]", cracker_path(cracker), "post" do
      assert_select "input[name=?]", "cracker[name]"

      assert_select "input[name=?]", "cracker[version]"

      assert_select "input[name=?]", "cracker[archive_file]"

      assert_select "input[name=?]", "cracker[active]"
    end
  end
end
