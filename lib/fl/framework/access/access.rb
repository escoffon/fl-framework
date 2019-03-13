require 'fl/framework/access/grants'

module Fl::Framework::Access
  # Access APIs.
  # This module defines two main classes of methods:
  # 1. Class methods to register new access checkers, or to override existing ones.
  #    See {Fl::Framework::Access::Access::ClassMethods#access_op}.
  # 2. Instance (and class) methods to check if an actor has access to an object.
  #    See {Fl::Framework::Access::Access::OldInstanceMethods#permission?} and
  #    {Fl::Framework::Access::Access::ClassMethods#default_access_checker}.
  # The methods in this module define and implement a framework for standardizing access control
  # management, but don't provide a specific access control algorithm.
  # Classes that include this module are expected to implement their own access check algorithms, typically
  # by overriding the default implementation of
  # {Fl::Framework::Access::Access::ClassMethods::default_access_checker}, or by
  # registering specialized access checker procs with
  # {Fl::Framework::Access::Access::ClassMethods::access_op}.
  #
  # The APIs use a generic object called an _actor_ as the entity that requests permission to perform
  # a given operation on an object. The type of _actor_ is left undefined, and it is expected that
  # users of this framework will provide their own specific types. Typically, this will be some kind of
  # user object, but it may be a software agent as well. The framework mostly passes the actor parameter
  # down to the methods that implement the specialized access control algorithms; these methods should
  # be aware of the nature of the actor entity.
  #
  # The module's {.included} method registers a number of standard operation types, using
  # +:default_access_checker+.
  # Since initially +:default_access_checker+ maps to either {ClassMethods#default_access_checker}
  # or {OldInstanceMethods#default_access_checker}, by default no permissions are granted: this forces classes
  # that include {Fl::Framework::Access::Access} to override the access policies as needed.
  # This can be done in one of two ways (or with a combination of these two ways):
  # 1. Override the class +:default_access_checker+ to implement the desired access policies.
  #    (The instance +:default_access_checker+ calls the class implementation, so typically one does not
  #    override the instance method.)
  # 2. Use {ClassMethods#access_op} to register a new access checker method that implements the desired
  #    access policies.
  #
  # === Examples
  # There are a few ways to use this framework. One is to define a mixin module that contains the access
  # algorithms, and include it to override the defaults:
  #   module MyAccess
  #     module ClassMethods
  #       def default_access_checker(op, obj, actor, context = nil)
  #         # (access check code here ...)
  #       end
  #     end
  #
  #     module OldInstanceMethods
  #     end
  #
  #     def self.included(base)
  #       base.extend ClassMethods
  #       base.instance_eval do
  #       end
  #       base.class_eval do
  #         include OldInstanceMethods
  #       end
  #     end
  #   end
  #
  #   class MyClass
  #     include Fl::Framework::Access::Access
  #     include MyAccess
  #   end
  # A variation on this is to override some default checks:
  #   class MyClass
  #     include Fl::Framework::Access::Access
  #     include MyAccess
  #
  #     access_op :read, :my_read_check
  #
  #     private
  #
  #     def my_write_check(op, obj, actor, context = nil)
  #       # (overridden check for :write ...)
  #     end
  #   end
  # If you don't need to share access check algorithms, you can embed them directly in a class:
  #   class MyClass
  #     include Fl::Framework::Access::Access
  #
  #     def self.default_access_checker(op, obj, actor, context = nil)
  #       case op.op
  #       when Fl::Framework::Access::Grants::INDEX
  #         nil
  #       when Fl::Framework::Access::Grants::CREATE
  #         :ok
  #       when Fl::Framework::Access::Grants::READ
  #         :ok
  #       when Fl::Framework::Access::Grants::WRITE
  #         _complex_write_check(op, obj, actor, context)
  #       else
  #         nil
  #       end
  #     end
  #     
  #     private def self._complex_write_check(op, obj, actor, context)
  #       # (write check here ...)
  #     end
  #   end
  # You can also extend the set of operations for which access checks are implemented:
  #   module ExtendAccess
  #     CLASS_OP = :class_op
  #     INSTANCE_OP = :instance_op
  #   
  #     module ClassMethods
  #       def default_access_checker(op, obj, actor, context = nil)
  #         # (access check code here includes support for CLASS_OP and INSTANCE_OP ...)
  #       end
  #     end
  #   
  #     module OldInstanceMethods
  #     end
  #   
  #     def self.included(base)
  #       base.extend ClassMethods
  #   
  #       base.instance_eval do
  #       end
  #   
  #       base.class_eval do
  #         include OldInstanceMethods
  #   
  #         access_op(ExtendAccess::CLASS_OP, :default_access_checker, { context: :class })
  #         access_op(ExtendAccess::INSTANCE_OP, :default_access_checker, { context: :instance })
  #       end
  #     end
  #   end
  #   
  #   class ExtendAsset
  #     include Fl::Framework::Access::Access
  #     include ExtendAccess
  #   end
  # The ExtendAsset class will support access checks for the additional two operations; for example:
  #   actor = get_actor()
  #   if ExtendAsset.permission?(actor, ExtendAccess::CLASS_OP)
  #     # (do something at the ExtendAsset class level)
  #   end

  module Access
    # The methods in this module will be installed as class methods of the including class.
    # Of particular importance is {#has_access_control}, which is used to turn on access control for
    # the class.

    module ClassMacros
      # Turn on access control for a class.
      # This method registers the given access checker with the class.
      # It then injects the methods in {ClassMethods} as class methods, and those in
      # {InstanceMethods} as instance methods.
      # Finally, it calls {Fl::Framework::Access::Checker#configure} on *checker*, passing `self`;
      # the checker may modify the class declaration as needed.
      #
      # @param checker [Fl::Framework::Access::Checker] The checker to use for access control.
      # @param cfg [Hash] A hash containing configuration parameters.
      #
      # @raise [RuntimeError] Raises an exception if *checker* is not an instance of
      #  {Fl::Framework::Access::Checker}.
      
      def has_access_control(checker, *opts)
        unless checker.is_a?(Fl::Framework::Access::Checker)
          raise "access checker is a #{checker.class.name}, should be a Fl::Framework::Access::Checker"
        end
        
        self.class_variable_set(:@@_access_checker, checker)

        self.send(:extend, Fl::Framework::Access::Access::ClassMethods)
        self.send(:include, Fl::Framework::Access::Access::InstanceMethods)

        checker.configure(self)
      end

      # Get the access checker.
      #
      # @return [Fl::Framework::Access::Checker] Returns the value that was passed to {#has_access_control}.

      def access_checker()
        self.class_variable_get(:@@_access_checker)
      end
    end

    # The methods in this module are installed as class method of the including class.
    # Note that these methods are installed by {ClassMacros#has_access_control}, so that only classes
    # that use access control implement these methods.

    module ClassMethods
      # Check if this model supports access control.
      #
      # @return [Boolean] Returns `true` if the model has access control functionality.
      
      def has_access_control?
        true
      end

      # Check if an actor has permission to perform an operation on an asset.
      # The *actor* requests permission *permission* on `self`.
      #
      # There is a permission request method for class objects, because some operations are performed
      # at the class level; the typical example is running a query as part of the implementation of
      # and `index` action.
      #
      # Because this method is a wrapper around {Fl::Framework::Access::Checker#access_check}, it has
      # essentially the same behavior.
      #
      # @param permission [Symbol,String] The name of the requested permission.
      # @param actor [Object] The actor requesting permissions.
      # @param context An arbitrary value containing the context in which to do the check.
      #
      # @return [Symbol,nil,Boolean] If *actor* is granted permission, the permission name is returned
      #  as a symbol (this is typically the value of *permission*).
      #  Note that the returned value may be different from *permission* if the permission is granted through
      #  forwarding (for example, if the request was for **:write** and it was granted because of a
      #  **:edit** permission).
      #  If access grants were not granted, the return value is `nil`.
      #  A `false` return value indicates that an error occurred while performing the access check, and
      #  should be interpreted as a denial.

      def has_permission?(permission, actor, context = nil)
        self.access_checker.access_check(permission, actor, self, context)
      end
    end
    
    # The methods in this module are installed as instance method of the including class.
    # Note that these methods are installed by {ClassMacros#has_access_control}, so that only classes
    # that use access control implement these methods.

    module InstanceMethods
      # Set the access checker.
      # Individual instances of the base class have the option of overriding the class access checker to
      # install custom access rights management.
      # This is not a common occurrence, because it opens potential security holes, but is provided so
      # that you can shoot yourself in the foot if you desire so.
      #
      # @param checker [Fl::Framework::Access::Checker] The checker to install for this instance.
      #  A `nil` value clears the access checker, which reverts back to the class access checker.

      def access_checker=(checker)
        if checker.nil?
          self.remove_instance_variable(:@_instance_access_checker)
        else
          self.instance_variable_set(:@_instance_access_checker, checker)
        end
      end

      # Get the access checker.
      # If an instance access checker has been defined, it is returned.
      # Otherwise, the method forwards the call to the class method by the same name
      # ({Fl::Framework::Access::Access::ClassMethods#access_checker}).
      #
      # @return [Fl::Framework::Access::Checker] Returns the value that was passed to {#has_access_control}.

      def access_checker()
        if self.instance_variable_defined?(:@_instance_access_checker)
          self.instance_variable_get(:@_instance_access_checker)
        else
          self.class.access_checker()
        end
      end

      # Check if an actor has permission to perform an operation on an asset.
      # The *actor* requests permission *permission* on `self`.
      # The method gets the current access checker from {#access_checker}, and trigger a call to
      # {Fl::Framework::Access::Checker#access_check}.
      # Because  is a wrapper around {Fl::Framework::Access::Checker#access_check}, it has
      # essentially the same behavior.
      #
      # The common case is that the class access checker is used; however, if individual instances
      # have installed their own access checker, that object is used instead.
      #
      # @param permission [Symbol,String] The name of the requested permission.
      # @param actor [Object] The actor requesting permissions.
      # @param context An arbitrary value containing the context in which to do the check.
      #
      # @return [Symbol,nil,Boolean] If *actor* is granted permission, the permission name is returned
      #  as a symbol (this is typically the value of *permission*).
      #  Note that the returned value may be different from *permission* if the permission is granted through
      #  forwarding (for example, if the request was for **:write** and it was granted because of a
      #  **:edit** permission).
      #  If access grants were not granted, the return value is `nil`.
      #  A `false` return value indicates that an error occurred while performing the access check, and
      #  should be interpreted as a denial.

      def has_permission?(permission, actor, context = nil)
        self.access_checker.access_check(permission, actor, self, context)
      end
    end

    # Perform actions when the module is included.
    # - Injects the class macros, to make {ClassMacros#has_access_control} available. Additional class
    #   and instance methods are injected by {ClassMacros#has_access_control}.

    def self.included(base)
      base.extend ClassMacros

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end

class ActiveRecord::Base
  # Backstop class access control checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as having access control support.
  #
  # @return [Boolean] Returns `false`; {Fl::Framework::Asset::Asset::ClassMacros#has_access_control}
  #  overrides the implementation to return `true`.
  
  def self.has_access_control?
    false
  end

  # Instance asset checker.
  # Calls the class method {.has_access_control?} and returns its return value.
  #
  # @return [Boolean] Returns the return value from {.has_access_control?}.
  
  def has_access_control?
    self.class.has_access_control?
  end
end
