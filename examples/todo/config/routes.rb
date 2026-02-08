Rails.application.routes.draw do
  mount LcpRuby::Engine => "/admin"
  root to: redirect("/admin/lists")
end
