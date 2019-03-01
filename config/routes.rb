Fl::Framework::Engine.routes.draw do
  resources :comments, :only => [ :show, :edit, :update, :destroy ] do
    resources :attachments, only: [ :index, :create ], controller: 'comment_attachments'
  end

  resources :attachments, :only => [ :show, :edit, :update, :destroy ]

  resources :lists do
    member do
      post 'add_object'
    end
  end

  resources :list_items do
  end
end
