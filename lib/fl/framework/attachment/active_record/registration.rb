require 'fl/framework/attachment/constants'
require 'fl/framework/attachment/registration'

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
      #  +has_attached_file+, possibly after processing if it contains the keys *:_alias*, *:_type*,
      #  and *:_delayed* as described below. In addition to *:_alias*, *:_type*, *:_delayed*, and the
      #  standard Paperclip configuration options, this hash may contain configuration options for additional
      #  processors; for example, see {Paperclip::Floopnail}, which is added to the Paperclip processor for
      #  many of the standard image-based attachment types.
      # @option opts [Symbol] :_type is the attachment type; it should be one of the types registered with
      #  {Fl::Framework::Attachment::ConfigurationDispatcher}. If this option is present, the default
      #  configuration options are obtained from the {Fl::Framework::Attachment::ConfigurationDispatcher#config}
      #  method.
      #  All other options in _opts_ are then merged into this default value. So, when this option is present,
      #  the other options are overrides to the standard type configuration.
      # @option opts [Symbol] :_alias is an alternate name for the attachment (in addition to _name_), and will
      #  be registered using the Ruby +alias+ directive. The rational for this feature is to support
      #  Single Table Inheritance of attachment objects: the STI table contains a single attachment
      #  reference (often +:attachment+), and subclasses all have to call {#activerecord_attachment} using
      #  the STI table's field name (+:attachment+ in this example).
      #  This feature aliases all +attachment_+ methods to +myatt_+ methods, where +myatt+ is the value
      #  of the *:_alias* option: consumers of the API can then use the +myattr+ variant to refer to the
      #  attachment, which makes the code a bit more readable.
      # @option opts [Boolean] :_delayed indicates if the attachment is to be processed "inline," or if it
      #  should be put in a queue for later processing using +delayed_paperclip+.
      #  Set to +false+ for inline processing; this is the default value, so if the option is not present,
      #  processing happens inline.
      #  To turn on delayed processing, set the value to +true+, or to a hash of options which will be passed
      #  to the +delayed_paperclip+ gem's +process_in_background+ method.

      def activerecord_attachment(name, opts = {})
        if opts.has_key?(:_type)
          cfg = Fl::Framework::Attachment.config[opts[:_type].to_sym].merge(opts)
          cfg.delete(:_type)
          delayed = opts[:_delayed]
          the_alias = opts[:_alias]
        else
          cfg = opts.dup
          delayed = cfg.delete(:_delayed)
          the_alias = cfg.delete(:_alias)
        end

        has_attached_file name.to_sym, cfg

        if the_alias.is_a?(Symbol)
          alias_attachment the_alias, name
        end

        if delayed
          # we want delayed processing: set up the configuration

          unless delayed.is_a?(Hash)
            delayed = { }
            delayed[:processing_image_url] = cfg[:processing_image_url] if cfg[:processing_image_url]
          end

          # now we can request that this attribute be processed in background

          process_in_background name.to_sym, delayed
        end
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
    end

    # Perform actions when the module is included.
    # - Injects the class methods and instance methods.
    # - In the context of the _base_ (and therefore of the comment class), includes the module
    #   {Fl::Framework::Attachment::Registration}.
    #
    # @param [Module] base The module or class that included this module.

    def self.included(base)
      base.extend ClassMethods

      base.send(:include, Fl::Framework::Attachment::Registration)
      base.send(:include, InstanceMethods)

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
