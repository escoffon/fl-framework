module Fl::Framework::List
  # Helpers for the list module.
  # Use it via `include`; the methods in {ClassMethods} are injected as class methods of the including
  # class.
  #
  # Alternatively, you can use it as a namespace for helper methods.
  # For example, {.make_listable} adds listable behavior to a class.

  module Helper
    # Enable listable support for a class.
    # Use this method to convert an existing class into a listable:
    #
    # ```
    # class TheClass < ActiverRecord::Base
    #   # class definition
    # end
    #
    # Fl::Framework::List::Helper.make_listable(TheClass, summary: :my_summary_method)
    # ```
    # See the documentation for {Listable::ClassMethods#is_listable}.
    # If the class is already marked as listable, the operation is skipped.
    #
    # @param klass [Class] The class object where listable behavior is enabled.
    # @param cfg [Hash] A hash containing configuration parameters. See the documentation for
    #  {Listable::ClassMethods#is_listable}.

    def self.make_listable(klass, *cfg)
      unless klass.listable?
        klass.send(:include, Fl::Framework::List::Listable)
        klass.send(:is_listable, *cfg)
      end
    end

    # Convert an actor parameter to an object.
    # This is a wrapper around {Fl::Framework::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Framework::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the owner, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Framework::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.actor_from_parameter(p, key = :actor)
      Fl::Framework::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Convert a listable parameter to an object.
    # This is a wrapper around {Fl::Framework::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Framework::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the listable, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Framework::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.listable_from_parameter(p, key = :listable)
      Fl::Framework::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Convert a list parameter to an object.
    # This is a wrapper around {Fl::Framework::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Framework::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the owner, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Framework::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.list_from_parameter(p, key = :list)
      Fl::Framework::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Perform actions when the module is included.
    #
    # - Adds to the including class the instance methods `actor_from_parameter`, `list_from_parameter`,
    #   and `listable_from_parameter` that forward the calls to {.owner_from_parameter},
    #   {.list_from_parameter}, and {.listable_from_parameter}, respectively.

    def self.included(base)
      base.class_eval do
        # include InstanceMethods

        def actor_from_parameter(p, key = nil)
          Fl::Framework::List::Helper.actor_from_parameter(p, key)
        end

        def list_from_parameter(p, key = nil)
          Fl::Framework::List::Helper.list_from_parameter(p, key)
        end

        def listable_from_parameter(p, key = nil)
          Fl::Framework::List::Helper.listable_from_parameter(p, key)
        end
      end
    end
  end
end
