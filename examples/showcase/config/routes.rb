Rails.application.routes.draw do
  mount LcpRuby::Engine => "/showcase"
  root to: redirect("/showcase/showcase-dashboard")
end
