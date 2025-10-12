class Railsboot::ErrorsComponent < Railsboot::Component
  def initialize(*objects, **html_attributes)
    @objects = Array(objects)
    @html_attributes = html_attributes
  end

  def errors
    @objects.map(&:errors).flatten
  end

  def error_messages
    errors.map(&:full_messages).flatten
  end

  def render?
    error_messages.any?
  end
end
