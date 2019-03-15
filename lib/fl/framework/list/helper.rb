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

    # Class methods.

    module ClassMethods
      protected

      # Convert an owner list to an array of fingerprints.
      #
      # @param ul [Array<ActiveRecord::Base,String>] The list of owners to convert; each element is either
      #  an ActiveRecord instance, or a string containing a fingerprint. Any other types are ignored by the
      #  conversion and will not appear in the return value.
      #
      # @return [Array<String>] Returns an array where the elements are string containing the fingerprints
      #  of the input elements.
      
      def _convert_owner_list(ul)
        ul.reduce([ ]) do |acc, u|
          case u
          when ActiveRecord::Base
            acc << "#{u.class.name}/#{u.id}"
          when String
            # Technically, we could get the class from the name, check that it exists and that it is
            # a subclass of ActiveRecord::Base, but for the time being we don't
            
            c, id = ActiveRecord::Base.split_fingerprint(u)
            acc << u unless c.nil? || id.nil?
          end

          acc
        end
      end

      # Partition an owner list.
      # The method extracts **:only_owners** and **:except_owners** from *opts*, and generates cleaned
      # up and streamlined return values for them.
      #
      # @param opts [Hash] Has of options.
      #
      # @return [Hash] Returns a hash containing the two keys **:only_owners** and **:except_owners**
      #  (typically either one or the other).
      
      def _partition_owner_lists(opts)
        rv = { }

        if opts.has_key?(:only_owners)
          if opts[:only_owners].nil?
            rv[:only_owners] = nil
          else
            only_o = (opts[:only_owners].is_a?(Array)) ? opts[:only_owners] : [ opts[:only_owners] ]
            rv[:only_owners] = _convert_owner_list(only_o)
          end
        end

        if opts.has_key?(:except_owners)
          if opts[:except_owners].nil?
            rv[:except_owners] = nil
          else
            x_o = (opts[:except_owners].is_a?(Array)) ? opts[:except_owners] : [ opts[:except_owners] ]
            except_owners = _convert_owner_list(x_o)

            # if there is a :only_owners, then we need to remove the :except_owners members from it.
            # otherwise, we return :except_owners

            if rv[:only_owners].is_a?(Array)
              rv[:only_owners] = rv[:only_owners] - except_owners
            else
              rv[:except_owners] = except_owners
            end
          end
        end

        rv
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
    # - Injects the methods in {ClassMethods} as class methods.
    # - Adds to the including class the instance methods `actor_from_parameter`, `list_from_parameter`,
    #   and `listable_from_parameter` that forward the calls to {.owner_from_parameter},
    #   {.list_from_parameter}, and {.listable_from_parameter}, respectively.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

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
