require 'rails_helper'

RSpec.describe "attacks/edit", type: :view do
  let(:attack) {
    Attack.create!()
  }

  before(:each) do
    assign(:attack, attack)
  end

  it "renders the edit attack form" do
    render

    assert_select "form[action=?][method=?]", attack_path(attack), "post" do
    end
  end
end
