require 'paperclip'
require 'nokogiri'

require 'fl/framework/rails/routes'

module Fl
  module Framework
    # Rails engine class for Fl::Framework.

    class Engine < ::Rails::Engine
      isolate_namespace Fl::Framework

      # We load the framework at the last step, after Paperclip has loaded.
      # Otherwise, the active record attachment code fails because has_attached_file has not
      # yet been defined.

      initializer '9900.fl_framework.load' do |app|
        # First, we need to load the initializer with the standard attachments, because the attachment
        # code makes use of standard attachment types.

        init_file = File.join(Rails.root, 'config', 'initializers', 'fl_attachments.rb');
        if File.exist?(init_file)
          require init_file
        else
          msg = "WARNING: the initializer file config/fl_attachments.rb was not found. The fl-framework attachment classes may be misconfigured."
          warn(msg)
          Rails.logger.warn(msg)
        end

        # OK, now we can load the rest of the fl-framework package

        if defined?(Neo4j)
          require 'fl/framework/neo4j'
        end

        require 'fl/framework/core'
        require 'fl/framework/query'
        require 'fl/framework/access'
        require 'fl/framework/comment'
        require 'fl/framework/attachment'
        require 'fl/framework/service'
        require 'fl/framework/controller'
        require 'fl/framework/test'
        require 'fl/framework/captcha'

        require 'fl/framework/active_record'
        require 'fl/framework/application_record'

        require 'fl/framework/list'
        
        require 'fl/google'

        require 'fl/framework/generator_helper'

        # and let's add the locale files. How do we manage if the users want to customize?

        config.i18n.load_path.concat(Dir[File.expand_path('../locales/framework/*.yml', __FILE__)])
        config.i18n.load_path.concat(Dir[File.expand_path('../locales/google/*.yml', __FILE__)])
      end
    end
  end
end
