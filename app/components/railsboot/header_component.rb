class Railsboot::HeaderComponent < Railsboot::Component
  renders_one :heading, lambda { |tag: "h2", **html_attributes|
    html_attributes[:class] = class_names("mb-0", html_attributes[:class])
    Railsboot::HeadingComponent.new(tag: tag, **html_attributes)
  }

  renders_one :breadcrumb, lambda { |**html_attributes|
    html_attributes[:class] = class_names("mt-0 mb-1 fw-light", html_attributes[:class])
    Railsboot::BreadcrumbComponent.new(**html_attributes)
  }

  renders_one :actions
end
