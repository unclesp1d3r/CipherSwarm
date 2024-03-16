require 'rails_helper'

RSpec.describe "attacks/show", type: :view do
  before(:each) do
    assign(:attack, Attack.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
