class HomeController < ApplicationController
  include Pundit::Authorization

  def index
  end
end
