require 'rails_helper'

RSpec.describe "crackers/new", type: :view do
  before(:each) do
    assign(:cracker, Cracker.new(
      name: "MyString",
      version: "MyString",
      archive_file: nil,
      active: false
    ))
  end

  it "renders new cracker form" do
    render

    assert_select "form[action=?][method=?]", crackers_path, "post" do
      assert_select "input[name=?]", "cracker[name]"

      assert_select "input[name=?]", "cracker[version]"

      assert_select "input[name=?]", "cracker[archive_file]"

      assert_select "input[name=?]", "cracker[active]"
    end
  end
end
