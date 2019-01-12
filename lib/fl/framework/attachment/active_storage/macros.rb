module Fl::Framework::Attachment::ActiveStorage
  # Namespace for ActiveStorage macros.

  module Macros
    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # Wraps the ActiveStorage `has_one_attached` to add the **:styles** option.
      #
      # @param name [Symbol,String] The name of the attachment attribute.
      # @param opts [Hash] Options for the validator.
      #
      # @option [Hash] :styles A hash of styles.
    
      def has_one_attached(name, dependent: :purge_later, styles: { })
        send(:has_one_attached_orig, name, dependent: dependent)

        class_eval do
          define_method("#{name}_styles") { styles }

          define_method("#{name}_style") do |sname|
            s = send("#{name}_styles")
            s[sname.to_sym] || { }
          end
          
          define_method("#{name}_style_variant") do |sname|
            send("#{name}").variant(send("#{name}_style", sname))
          end
          
          define_method("#{name}_style_path") do |sname|
            v = send("#{name}_style_variant", sname)
            Rails.application.routes.url_helpers.rails_blob_representation_path(v.blob.signed_id,
                                                                                v.variation.key,
                                                                                v.blob.filename)
          end
          
          define_method("#{name}_style_url") do |sname, *opts|
            v = send("#{name}_style_variant", sname)
            Rails.application.routes.url_helpers.rails_blob_representation_url(v.blob.signed_id,
                                                                               v.variation.key,
                                                                               v.blob.filename,
                                                                               *opts)
          end
        end
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods.

    def self.included(base)
      base.instance_eval do
        alias has_one_attached_orig has_one_attached
      end
      
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
