require 'rails_helper'

RSpec.describe "attacks/index", type: :view do
  before(:each) do
    assign(:attacks, [
      Attack.create!(),
      Attack.create!()
    ])
  end

  it "renders a list of attacks" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
