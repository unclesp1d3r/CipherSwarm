require 'rails_helper'

RSpec.describe "cracker_binaries/index", type: :view do
  before(:each) do
    assign(:cracker_binaries, [
      CrackerBinary.create!(
        version: "Version",
        active: false,
        cracker: nil
      ),
      CrackerBinary.create!(
        version: "Version",
        active: false,
        cracker: nil
      )
    ])
  end

  it "renders a list of cracker_binaries" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new("Version".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
