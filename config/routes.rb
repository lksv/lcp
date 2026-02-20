LcpRuby::Engine.routes.draw do
  # Devise routes are always mounted so that URL helpers are available.
  # Access is controlled by the controllers (require_built_in_auth! guard).
  devise_for :users,
    class_name: "LcpRuby::User",
    module: "lcp_ruby/auth",
    path: "auth",
    router_name: :lcp_ruby,
    path_names: {
      sign_in: "login",
      sign_out: "logout",
      sign_up: "register",
      password: "password"
    }

  post   "impersonate",      to: "impersonation#create",  as: :impersonate
  delete "impersonate",      to: "impersonation#destroy", as: :stop_impersonate

  scope ":lcp_slug" do
    get    "/",          to: "resources#index",   as: :resources
    get    "/select_options",      to: "resources#select_options",      as: :select_options
    get    "/inline_create_form",  to: "resources#inline_create_form",  as: :inline_create_form
    post   "/inline_create",       to: "resources#inline_create",       as: :inline_create
    get    "/new",       to: "resources#new",     as: :new_resource
    post   "/",          to: "resources#create",  as: :create_resource
    post   "/evaluate_conditions",     to: "resources#evaluate_conditions_new", as: :evaluate_conditions_new
    get    "/:id",       to: "resources#show",    as: :resource
    get    "/:id/edit",  to: "resources#edit",    as: :edit_resource
    patch  "/:id",       to: "resources#update",  as: :update_resource
    put    "/:id",       to: "resources#update"
    delete "/:id",       to: "resources#destroy", as: :destroy_resource
    post   "/:id/evaluate_conditions", to: "resources#evaluate_conditions",     as: :evaluate_conditions
    post   "/actions/:action_name",       to: "actions#execute_collection", as: :collection_action
    post   "/:id/actions/:action_name",   to: "actions#execute_single",     as: :single_action
    post   "/batch_actions/:action_name", to: "actions#execute_batch",      as: :batch_action
  end
end
