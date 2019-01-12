module Fl::Framework::Attachment::ActiveStorage
  # Namespace for ActiveStorage validators.

  module Validation
    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # Registers a validator for the content type of an attachment.
      # Validates that the attachment named *name* has a `content_type` property that matches one
      # from *content_types*.
      #
      # @param name [Symbol,String] The name of the attachment attribute.
      # @param opts [Hash] Options for the validator.
      #
      # @option [Array<String,RegExp>] :content_types An array of content types to match. Each element is
      #  a string containing the content type (for example, `image/jpeg'), or a "glob" pattern like
      #  `image/*`.
      #  Defaults to `[ 'image/*' ]`.
    
      def has_one_attached_validate_content_type(name, opts = {})
        content_types = opts[:content_types] || [ 'image/*' ]
        lo_content_types = content_types.map { |ct| ct.downcase }

        c = Class.new(ActiveModel::Validator)
        c.class_eval do
          define_method :validate do |record|
            attachment = record.send(name)
            ctype = attachment.content_type.downcase
            lo_content_types.each do |ct|
              return if ct == ctype
              return if File.fnmatch(ct, ctype)
            end
            record.errors.add(name.to_sym, I18n.tx('fl.framework.attachment.active_storage.model.validate.forbiddent_content_type',
                                                   ctype: ctype))
          end
        end

        validates_with c
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
