require 'paperclip'
require 'nokogiri'

require 'fl/framework/rails/routes'

module Fl
  module Framework
    # Rails engine class for Fl::Framework.

    class Engine < ::Rails::Engine
      isolate_namespace Fl::Framework

      locale_path = Dir.glob(File.dirname(__FILE__) + "/locales/*.{rb,yml}")
      I18n.load_path += locale_path unless I18n.load_path.include?(locale_path)

      # We load the framework at the last step, after Paperclip has loaded.
      # Otherwise, the active record attachment code fails because has_attached_file has not
      # yet been defined.

      initializer '9999.fl_framework.load' do |app|
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

        require 'fl/framework/active_record'
        require 'fl/framework/application_record'
      end
    end
  end
end
