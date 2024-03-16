require 'rails_helper'

RSpec.describe "attacks/new", type: :view do
  before(:each) do
    assign(:attack, Attack.new())
  end

  it "renders new attack form" do
    render

    assert_select "form[action=?][method=?]", attacks_path, "post" do
    end
  end
end
