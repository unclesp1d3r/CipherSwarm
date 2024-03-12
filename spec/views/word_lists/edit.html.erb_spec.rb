require 'rails_helper'

RSpec.describe "word_lists/edit", type: :view do
  let(:word_list) {
    WordList.create!(
      name: "MyString",
      description: "MyText",
      file: nil,
      line_count: 1,
      sensitive: false
    )
  }

  before(:each) do
    assign(:word_list, word_list)
  end

  it "renders the edit word_list form" do
    render

    assert_select "form[action=?][method=?]", word_list_path(word_list), "post" do
      assert_select "input[name=?]", "word_list[name]"

      assert_select "textarea[name=?]", "word_list[description]"

      assert_select "input[name=?]", "word_list[file]"

      assert_select "input[name=?]", "word_list[line_count]"

      assert_select "input[name=?]", "word_list[sensitive]"
    end
  end
end
