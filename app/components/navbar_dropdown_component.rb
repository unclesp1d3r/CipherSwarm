# frozen_string_literal: true

class NavbarDropdownComponent < ViewComponent::Base
  def initialize(title:)
    @title = title
  end
end
