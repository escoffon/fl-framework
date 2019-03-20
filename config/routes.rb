Fl::Framework::Engine.routes.draw do
  resources :comments, :only => [ :show, :edit, :update, :destroy ] do
    resources :attachments, only: [ :index, :create ], controller: 'comment_attachments'
  end

  resources :attachments, :only => [ :show, :edit, :update, :destroy ]

  resources :lists do
    member do
      post 'add_object'
    end
    resources :list_items, shallow: true, controller: 'list_items'
  end

  resources :list_items, only: [ :index ], controller: 'list_items' do
  end

  namespace :actor do
    resources :groups do
      member do
        post 'add_actor'
      end
      resources :group_members, shallow: true, controller: 'group_members'
    end

    resources :group_members, only: [ :index ], controller: 'group_members' do
    end
  end
end
