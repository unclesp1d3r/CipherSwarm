require 'rails_helper'

RSpec.describe "word_lists/new", type: :view do
  before(:each) do
    assign(:word_list, WordList.new(
      name: "MyString",
      description: "MyText",
      file: nil,
      line_count: 1,
      sensitive: false
    ))
  end

  it "renders new word_list form" do
    render

    assert_select "form[action=?][method=?]", word_lists_path, "post" do
      assert_select "input[name=?]", "word_list[name]"

      assert_select "textarea[name=?]", "word_list[description]"

      assert_select "input[name=?]", "word_list[file]"

      assert_select "input[name=?]", "word_list[line_count]"

      assert_select "input[name=?]", "word_list[sensitive]"
    end
  end
end
