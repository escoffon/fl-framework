module Fl::Framework::Attachment::Neo4j
  # Extension module for use by objects that manage attachments.
  # This module defines common functionality for all model classes that manage attachments.

  module Master
    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
      # Add attachment master behavior to a model.
      # This class method registers the APIs used to manage attachments:
      # - Adds an association to track attachments (as a +:has_many+ association).
      # - Define the {#can_attach?} method to return +true+ to indicate that the class supports attachments.
      # - Loads the instance methods from Fl::Attachment::Master::InstanceMethods.
      #
      # @overload has_attachments()
      #  When used with no arguments, the method creates an association called *attachments* that
      #  manages all attachment types via the +ATTACHED_TO+ relationship.
      # @overload has_attachments(name, cfg = {})
      #  Creates an association using the name in _name_ that manages attachment types via a given
      #  relationship (which defaults to +ATTACHED_TO+).
      #  @param name [Symbol] The association name.
      #  @param cfg [Hash] A hash containing configuration parameters.
      #  @option cfg [Symbol, String] :rel_class The relationship class to use for the association.
      #   The default is <tt>:'Fl::Rel::Attachment::AttachedTo'</tt>, which uses the +ATTACHED_TO+ relationship.
      #  @option cfg [Symbol] :dependent How to dispose of dependent objects (the attachments). This is
      #   passed to the association. Defaults to +:destroy+.

      def has_attachments(*args)
        opts = {
          rel_class: :'Fl::Rel::Attachment::AttachedTo',
          dependent: :destroy
        }

        case args.count
        when 0
          name = :attachments
        when 1
          name = args[0].to_sym
        else
          name = args[0].to_sym
          h = args[1]
          if h.is_a?(Hash)
            opts[:rel_class] = h[:rel_class] if h.has_key?(:rel_class)
            opts[:dependent] = h[:dependent] if h.has_key?(:dependent)
          end
        end

        # This association tracks the attachments associated with an object.

        has_many :in, name, opts

        unless include?(Fl::Attachment::Master::InstanceMethods)
          include Fl::Attachment::Master::InstanceMethods
        end

        def can_attach?()
          true
        end
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Check if the model supports attachments.
      #
      # @return [Boolean] Returns the value returned by the class method by the same name.

      def can_attach?()
        self.class.can_attach?()
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods. Instance methods will be injected if #has_attachments is called.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        # include InstanceMethods
      end
    end
  end
end
