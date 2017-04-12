module ActionDispatch::Routing
  class Mapper
    def mount_comments_for(resource, opts = {})
      print("++++++++++ in mount_comments_for scope: #{@scope[:path]}\n")

      Fl::Framework::Engine.routes.draw do
        resources :campgrounds, only: [ ] do
          resources :comments, only: [ :index, :new, :create ], :controller => '/fl/framework/comments'
        end
      end
    end
  end
end
