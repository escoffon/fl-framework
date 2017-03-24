module Fl::Framework::Attachment::Neo4j
  # Mixin module that defines the registration API for attachments for Neo4j databases.
  # When this module is included, the {ClassMethods#neo4j_attachment} class method is defined that can be
  # used to declare an attachment property. This method is a wrapper around the neo4jrb-paperclip
  # ({https://github.com/neo4jrb/neo4jrb-paperclip}) gem's +has_neo4jrb_attached_file+.

  module Registration
    # Methods that override the Paperclip::Delayed implementation
    # Some methods defined by Delayed::Paperclip assume ActiveRecord, and therefore SQL semantics/syntax,
    # which is not quite the same as Neo4j's.
    # So we we override the Delayed::Paperclip version to be Neo4j friendly.

    module PaperclipDelayedOverrides
      # Sets the _name_*_proceesing* flag to +true+ for all attachments that were scheduled for delayed
      # processing.
      #
      # This implementation fixes the update statement so that it is generated correctly for Cypher.

      def mark_enqueue_delayed_processing
        unless @_enqued_for_processing_with_processing.blank? # catches nil and empty arrays
          updates = @_enqued_for_processing_with_processing.collect{|n| "n.#{n}_processing = true" }.join(", ")
          self.class.as(:n).where(:id => self.id).update_all(updates)
        end
      end
    end

    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Add a Neo4j attachment.
      # This class method registers the APIs used to manage attachments:
      # - Ensures that the including class has included the Neo4j::ActiveNode module.
      # - Ensures that the including class includes the Neo4jrb::Paperclip module.
      # - Sets up the attachment configuration parameters, and then calls +has_neo4jrb_attached_file+
      #   to register an attachment.
      # - If the attachment is marked for delayed processing, sets that up.
      #
      # Note that this method does *not* install any validations on the attachment, which is left to the
      # client to do. In particular, since Paperclip has some strict requirements on the presence of some
      # types of validation, at least +validates_attachment_content_type+ will have to be called by the
      # client.
      #
      # @param name [Symbol] The attachment's name. This is the name under which the attachment is available
      #  in +self+. It is passed as the name argument to +has_neo4jrb_attached_file+
      # @param opts [Hash] A hash containing configuration parameters. This hash is passed to 
      #  +has_neo4jrb_attached_file+, possibly after processing if it contains the key *:_type*
      #  as described below. In addition to *:_type* and the standard Paperclip configuration options,
      #  this hash may contain configuration options for additional processors; for example, see
      #  {Paperclip::Floopnail}, which is added to the Paperclip processor for many of the standard
      #  image-based attachment types.
      # @option cfg [Symbol] :_type is the attachment type; it should be one of the types registered with
      #  {Fl::Attachment::ConfigurationDispatcher}. If this option is present, the default configuration
      #  options are obtained from the {Fl::Attachment::ConfigurationDispatcher#config} method.
      #  All other options in _opts_ are then merged into this default value. So, when this option is present,
      #  the other options are overrides to the standard type configuration.
      # @option cfg [Boolean] :_delayed indicates if the attachment is to be processed "inline," or if it
      #  should be put in a queue for later processing using something like +delayed_paperclip+.
      #  Set to +false+ for inline processing; this is the default value, so if the option is not present,
      #  processing happens inline.
      #  To rutn on delayed processing, set the value to +true+, or to a hash of options which will be passed
      #  to the +delayed_paperclip+ gem's +process_in_background+ method.

      def neo4j_attachment(name, opts = {})
        # attachments require a Neo4j node object

        unless self.include?(Neo4j::ActiveNode)
          raise "internal error: class #{self.name} must include Fl::Neo4j::ActiveNode to support attachments"
        end

        unless self.include?(Neo4jrb::Paperclip)
          include Neo4jrb::Paperclip
        end

        if opts.has_key?(:_type)
          cfg = Fl::Attachment.config[opts[:_type].to_sym].merge(opts)
          cfg.delete(:_type)
        else
          cfg = opts.dup
        end

        has_neo4jrb_attached_file name.to_sym, cfg

        if opts[:_delayed]
          # we want delayed processing: first, set up the class by picking up the delayed_paperclip
          # extensions and the delayed_paperclip overrides, and then defining the :unscoped method (which
          # delayed_paperclip assumes, since it assumes that it is running in the context of an ActiveRecord
          # class)

          unless self.include?(DelayedPaperclip::Glue)
            include DelayedPaperclip::Glue
          end

          unless self.include?(PaperclipDelayedOverrides)
            include PaperclipDelayedOverrides
          end

          def self.unscoped()
            return self
          end

          # Then, add the _processing property to mark the attachment "in progress"

          property "#{name}_processing".to_sym, type: Neo4j::Shared::Boolean

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
