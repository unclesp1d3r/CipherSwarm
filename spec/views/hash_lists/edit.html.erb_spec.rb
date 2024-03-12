require 'rails_helper'

RSpec.describe "hash_lists/edit", type: :view do
  let(:hash_list) {
    HashList.create!(
      name: "MyString",
      description: "MyText",
      file: nil,
      line_count: 1,
      sensitive: false,
      hash_mode: 1
    )
  }

  before(:each) do
    assign(:hash_list, hash_list)
  end

  it "renders the edit hash_list form" do
    render

    assert_select "form[action=?][method=?]", hash_list_path(hash_list), "post" do
      assert_select "input[name=?]", "hash_list[name]"

      assert_select "textarea[name=?]", "hash_list[description]"

      assert_select "input[name=?]", "hash_list[file]"

      assert_select "input[name=?]", "hash_list[line_count]"

      assert_select "input[name=?]", "hash_list[sensitive]"

      assert_select "input[name=?]", "hash_list[hash_mode]"
    end
  end
end
