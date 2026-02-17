LcpRuby::Engine.routes.draw do
  scope ":lcp_slug" do
    get    "/",          to: "resources#index",   as: :resources
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
