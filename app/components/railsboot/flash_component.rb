class Railsboot::FlashComponent < Railsboot::Component
  FLASH_TYPES = [:notice, :alert, :info].freeze
  FLASH_MAPPING = {
    notice: "success",
    alert: "danger",
    info: "info"
  }.freeze

  def initialize(flash:, **html_attributes)
    @flash = flash
    @html_attributes = html_attributes
  end

  def render?
    @flash.present?
  end
end
