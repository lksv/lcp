Rails.application.routes.draw do
  mount LcpRuby::Engine => "/hr"
  root to: redirect("/hr/employees")
end
