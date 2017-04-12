Fl::Framework::Engine.routes.draw do
  resources :comments, :only => [ :show, :edit, :update, :destroy ]
end
