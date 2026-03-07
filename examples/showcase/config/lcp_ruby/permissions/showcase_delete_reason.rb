define_permissions :showcase_delete_reason do
  role :admin do
    crud :create
    presenters :all
  end

  role :editor do
    crud :create
    presenters :all
  end

  role :viewer do
    crud :create
    presenters :all
  end
end
