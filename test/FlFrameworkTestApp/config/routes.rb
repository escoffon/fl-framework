Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount Fl::Framework::Engine => "/fl/framework", :as => 'fl_framework'
  
  # START added by fl:framework:comments generator
  resources :test_datum_ones do
    # START added by fl:framework:attachments generator
    resources :attachments, only: [ :index, :create ], controller: 'test_datum_one_attachments'
    # END added by fl:framework:attachments generator
    resources :comments, only: [ :index, :create ], controller: 'test_datum_one_comments'
  end
  # END added by fl:framework:comments generator
end
