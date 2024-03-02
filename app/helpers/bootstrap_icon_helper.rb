module BootstrapIconHelper
  def icon(name)
    content_tag :i, nil, class: "bi bi-#{name}"
  end

  def boolean_icon(boolean)
    icon(boolean ? "check-square-fill" : "x-square-fill")
  end
end
