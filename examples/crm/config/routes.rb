Rails.application.routes.draw do
  mount LcpRuby::Engine => "/crm"
  root to: redirect("/crm/companies")
end
