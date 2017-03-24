module Fl::Framework::Attachment::ActiveRecord
  # Mixin module that defines the registration API for Active Record attachments.
  # When this module is included, the {ClassMethods#activerecord_attachment} class method is defined that
  # can be used to declare an attachment. This method is a wrapper around the paperclip
  # ({https://github.com/thoughtbot/paperclip}) gem's +has_attached_file+.

  module Registration
    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Add an ActiveRecord attachment.
      # This class method registers the APIs used to manage attachments:
      # - Sets up the attachment configuration parameters, and then calls +has_attached_file+
      #   to register an attachment.
      # - If the attachment is marked for delayed processing, sets that up.
      #
      # Note that this method does *not* install any validations on the attachment, which is left to the
      # client to do. In particular, since Paperclip has some strict requirements on the presence of some
      # types of validation, at least +validates_attachment_content_type+ will have to be called by the
      # client.
      #
      # Note also that the method expects that an appropriate migration has been run on the model's table
      # so that the Paperclip attributes have been defined.
      #
      # @param name [Symbol] The attachment's name. This is the name under which the attachment is available
      #  in +self+. It is passed as the name argument to +has_attached_file+
      # @param opts [Hash] A hash containing configuration parameters. This hash is passed to 
      #  +has_attached_file+, possibly after processing if it contains the keys *:_type* and *:_delayed*
      #  as described below. In addition to *:_type*, *_delayed*, and the standard Paperclip configuration
      #  options, this hash may contain configuration options for additional processors; for example, see
      #  {Paperclip::Floopnail}, which is added to the Paperclip processor for many of the standard
      #  image-based attachment types.
      # @option cfg [Symbol] :_type is the attachment type; it should be one of the types registered with
      #  {Fl::Framework::Attachment::ConfigurationDispatcher}. If this option is present, the default
      #  configuration options are obtained from the {Fl::Framework::Attachment::ConfigurationDispatcher#config}
      #  method.
      #  All other options in _opts_ are then merged into this default value. So, when this option is present,
      #  the other options are overrides to the standard type configuration.
      # @option cfg [Boolean] :_delayed indicates if the attachment is to be processed "inline," or if it
      #  should be put in a queue for later processing using +delayed_paperclip+.
      #  Set to +false+ for inline processing; this is the default value, so if the option is not present,
      #  processing happens inline.
      #  To turn on delayed processing, set the value to +true+, or to a hash of options which will be passed
      #  to the +delayed_paperclip+ gem's +process_in_background+ method.

      def activerecord_attachment(name, opts = {})
        if opts.has_key?(:_type)
          cfg = Fl::Framework::Attachment.config[opts[:_type].to_sym].merge(opts)
          cfg.delete(:_type)
        else
          cfg = opts.dup
        end

        has_attached_file name.to_sym, cfg

        if opts[:_delayed]
          # we want delayed processing: first, set up the class by picking up the delayed_paperclip
          # extensions and the delayed_paperclip overrides, and then defining the :unscoped method (which
          # delayed_paperclip assumes, since it assumes that it is running in the context of an ActiveRecord
          # class)

          #unless self.include?(DelayedPaperclip::Glue)
          #  include DelayedPaperclip::Glue
          #end

          #unless self.include?(PaperclipDelayedOverrides)
          #  include PaperclipDelayedOverrides
          #end

          #def self.unscoped()
          #  return self
          #end

          # now we can request that this attribute be processed in background

          process_in_background name.to_sym
        end
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
    end

    # Perform actions when the module is included.
    # - Injects the class methods and instance methods.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        include InstanceMethods
      end
    end
  end
end
