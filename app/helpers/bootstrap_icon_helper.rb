module BootstrapIconHelper
  def icon(name)
    content_tag :i, nil, class: "bi bi-#{name}"
  end
end
