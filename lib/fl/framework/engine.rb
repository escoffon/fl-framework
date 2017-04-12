require 'fl/framework/rails/routes'

module Fl
  module Framework
    # Rails engine class for Fl::Framework.

    class Engine < ::Rails::Engine
      isolate_namespace Fl::Framework
    end
  end
end
