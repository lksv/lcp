Rails.application.routes.draw do
  mount LcpRuby::Engine => "/"
  root to: redirect("/lists")
end
