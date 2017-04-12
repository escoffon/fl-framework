module Fl::Framework::Access
  # Access APIs.
  # This module defines two main classes of methods:
  # 1. Class methods to register new access checkers, or to override existing ones.
  #    See {Fl::Framework::Access::Access::ClassMethods#access_op}.
  # 2. Instance (and class) methods to check if an actor has access to an object.
  #    See {Fl::Framework::Access::Access::InstanceMethods#permission?} and
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
  # or {InstanceMethods#default_access_checker}, by default no permissions are granted: this forces classes
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
  #     module InstanceMethods
  #     end
  #
  #     def self.included(base)
  #       base.extend ClassMethods
  #       base.instance_eval do
  #       end
  #       base.class_eval do
  #         include InstanceMethods
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
  #     module InstanceMethods
  #     end
  #   
  #     def self.included(base)
  #       base.extend ClassMethods
  #   
  #       base.instance_eval do
  #       end
  #   
  #       base.class_eval do
  #         include InstanceMethods
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
    # A class to store access check information.
    # Instances of this class contain information about an operation.
    # See the documentation for {Fl::Framework::Access::Access::ClassMethods#access_op} for details.
    #
    # === Attributes
    # The following readonly attributes are defined:
    # - +op+ is a Symbol containing the operation name.
    # - +checker+ is a Symbol that contains the name of a method to be executed to determine access
    #   rights. It can also be a Proc object that implements the access rights algorithm.
    # - +config+ is a Hash of configuration parameters.
    # - +context+ is the +:context+ value in +config+.
    # - +grants+ is the +:grants+ value in +config+.
    # - +public+ is the +public+ value in +config+.

    class Checker
      # @!attribute [r]
      # @return [Symbol] the operation associated with this check.

      attr_reader :op

      # @!attribute [r]
      # @return [Hash] the configuration for this check.

      attr_reader :config

      # @!attribute [r]
      # @return [Symbol, Proc] the name of the check method or body of the check Proc.

      attr_accessor :checker

      attr_reader :context, :grants, :public

      # Initialize the object.
      #
      # @param op [Symbol, String] The operation name; the value is converted to a Symbol.
      # @param checker [Symbol, Proc] The name of the check method or body of the check Proc.
      # @param config [Hash] A Hash of configuration parameters.
      # @option config [Symbol] :context The context of the check call; currently
      #  two contexts are supported:
      #  - +:class+ The check call is made by a class object; for example, the +:index+ operation is
      #    run by a class object.
      #  - +:instance+ The check is made by a class instance; for example, the +:read+ operation is run
      #    by an instance.
      #  The default value is +:instance+.
      # @option config [Array<Symbol>] :grants The list of operations that are granted by this one.
      #  For example, a +:write+ operation also grants +:read+.
      # @option config [Boolean] :public A flag to control whether this operation grants access to public
      #  objects.

      def initialize(op, checker, config)
        @op = op.to_sym
        @checker = checker
        @config = config.is_a?(Hash) ? config.dup : {}
      end

      # @!attribute [r] context
      # @return [Symbol] the execution context for this access check.

      def context()
        return (@config.has_key?(:context)) ? @config[:context] : :instance
      end

      # @!attribute [r] grants
      # @return [Array<Symbol>] the list of permissions that are implicitly granted by thie access check;
      #  for example, a +:write+ permission also grants +:read+ permission.

      def grants()
        return (@config[:grants].is_a?(Array)) ? @config[:grants] : []
      end

      # @!attribute [r] public
      # @return [Boolean] +true+ if this check grants access to public objects, +false+ otherwise.

      def public()
        return @config[:public]
      end

      # Get the forward grants for this operation.
      # This method essentially tags the contents of the +grants+ attribute to the +op+ attribute.
      #
      # @return [Array<Symbol>] Returns an array containing the full list of operations for which access
      #  is granted by this operation.

      def forward_grants()
        [ self.op ] | self.grants
      end

      # Execute the checker method or Proc.
      # The arguments come from the #permission? call.
      #
      # @param obj The object granting (or denying) access.
      # @param actor [Object] The actor requesting access.
      # @param context The context in which to do the check.
      #
      # @return Returns the return value from the call to the checker.

      def run_check(obj, actor, context = nil)
        case self.checker
        when Proc
          self.checker.call(self, obj, actor, context)
        when Symbol
          obj.send(self.checker, self, obj, actor, context)
        else
          raise "internal error: bad access checker: #{self.checker}"
        end
      end
    end

    # The methods in this module will be installed as class methods of the including class.
    # Of particular importance is {#access_op}, which is used to register new access control operations
    # or modify existing ones. For example:
    #   class MyClass
    #     include Fl::Framework::Access::Access
    #
    #     access_op :new_operation, :my_check, context: :class
    #     access_op :write, :my_write_check
    #   end

    module ClassMethods
      # Register or override the access checker for an operation.
      #
      # If no operation is registered under +op+, the method creates an {Fl::Framework::Access::Access::Checker}
      # instance, passing the value of +op+ as the +op+ attribute, +checker+ or +cproc+ as the +checker+
      # attribute, and +opts+ as the +config+ attribute. If neither +checker+ nor +cproc+ are defined,
      # the default standard access check method is installed.
      #
      # If an operation is already registered, only the value of the +checker+ or +cproc+ attribute is
      # changed; this means that you can modify the access check algorithm, but not the overall semantics of
      # an already registered operation. Note that this also implies that either +checker+ or +cproc+
      # must be defined, which is different from the case where a new operation is installed.
      #
      # Note that defining both a +checker+ and a +cproc+ is inconsistent; in that case, +cproc+
      # is ignored.
      #
      # The *opts* configuration for the registration takes the following keys:
      # - *:context* defines the context of the check call: if +:class+,
      #   the check is performed from the class object; if +:instance+, from the instance object.
      #   The default value is +:instance+.
      # - *:grants* contains a list of operations that are granted by this one;
      #   for example, a +:moderate+ operation could be defined as an aggregation of +:read+ and +:write+
      #   to indicate that granting +:moderate+ rights implies granting +:read+ and +:write+ rights.
      #   When the access control code checks for +:write+ permissions, it expands aggregated
      #   permissions to check if they contain +:write+, and if so grants access.
      # - *:public* determines if this operation grants access to public objects: if its
      #   value is +true+, access is granted to objects with +:public+ visibility.
      #
      # The access check method or Proc are expected to take four arguments:
      # - *op* A {Checker} instance containing the operation descriptor.
      #   This is the instance that contains the operation's
      #   registration info, which includes the symbolized name of the operation and the configuration.
      # - *obj* The object granting permission.
      # - *actor* The actor requesting permission.
      # - *ctx* The context that was passed to the permission call.
      # If we compare these to the arguments to the {Fl::Framework::Access::InstanceMethods#permission?}
      # method, then:
      # - *op* is derived from the _op_ parameter of {Fl::Framework::Access::InstanceMethods#permission?}.
      # - *obj* is +self+ in {Fl::Framework::Access::InstanceMethods#permission?}.
      # - *actor* is _actor_ in {Fl::Framework::Access::InstanceMethods#permission?}.
      # - *ctx* is _context_ in {Fl::Framework::Access::InstanceMethods#permission?}.
      #
      # For example, here is a class that registers two additional access operations, one that uses a method,
      # and one that uses a block. It also registers a new access checker for the +:read+ operation.
      #   class MyClass
      #     include Fl::Framework::Access::Access
      #     include Fl::Framework::Access::Visibility
      #
      #     access_op Fl::Framework::Access::Grants::READ, :my_read_check
      #     access_op :my_op2, :my_op2_check, context: :instance
      #     access_op :my_op, context: :class { |op, obj, actor, ctx| ... }
      #
      #     private
      #
      #     def my_op2_check(op, obj, actor, context = nil)
      #       # custom check for :op2 here ...
      #     end
      #
      #     def my_read_check(op, obj, actor, context = nil)
      #       # cusom check for :read here ...
      #     end
      #   end
      # If the access rights are granted, the return value of the checker is a symbol describing the type
      # of permission that was granted; these symbols are implementation-dependent.
      # If access rights are not granted, the return value is +nil+.
      # Under some circumstances, the checker may elect to return +false+ to indicate that access was not
      # granted because of an error.
      # This return value is returned by {Fl::Framework::Access::InstanceMethods#permission?}.
      #
      # @overload access_op(op, checker, opts)
      #  Registers a new access control operation where the check implementation is provided as an
      #  instance method.
      #
      #  @param op [Symbol, String] The operation to register or override. The value is converted to a Symbol.
      #  @param checker [Symbol, String] The access control implementation.
      #   It is a String or a Symbol containing the name of a method that will be called to perform the
      #   access check.
      #  @param opts [Hash] Optional configuration for the registration.
      #
      # @overload access_op(op, opts, &cproc)
      #  Registers a new access control operation where the check implementation is provided as a block.
      #
      #  @param op [Symbol, String] The operation to register or override. The value is converted to a Symbol.
      #  @param opts [Hash] Optional configuration for the registration.
      #  @param cproc A block that contains the check algorithm implementation in line and that will be 
      #   converted into a Proc.
      #
      # @overload access_op(op, checker)
      #  Registers a new check implementation (as an instance method) for an existing operation.
      #
      #  @param op [Symbol, String] The operation to register or override. The value is converted to a Symbol.
      #  @param checker [Symbol, String] The access control implementation.
      #   It is a String or a Symbol containing the name of a method that will be called to perform the
      #   access check.
      #
      # @overload access_op(op, &cproc)
      #  Registers a new check implementation (as a block) for an existing operation.
      #
      #  @param op [Symbol, String] The operation to register or override. The value is converted to a Symbol.
      #  @param cproc A block that contains the check algorithm implementation in line and that will be 
      #   converted into a Proc.

      def access_op(op, *args, &cproc)
        a_c_ops = self.access_control_ops

        if args.count == 0
          checker = nil
          opts = {}
        elsif args[0].is_a?(String) || args[0].is_a?(Symbol)
          checker = args[0].to_sym
          opts = (args[1].is_a?(Hash)) ? args[1] : {}
        elsif args[0].is_a?(Hash)
          checker = nil
          opts = args[0]
        else
          checker = nil
          opts = {}
        end

        sop = op.to_sym
        if a_c_ops.has_key?(sop)
          raise 'missing symbol name or Proc body' if checker.nil? && cproc.nil?
          a_c_ops[sop].checker = (checker.nil?) ? cproc : checker
        else
          if checker.nil? && cproc.nil?
            proc = :default_access_checker
          else
            proc = (checker.nil?) ? cproc : checker
          end
          config = ({ context: :instance }).merge(opts)
          a_c_ops[sop] = Checker.new(sop, proc, config)
          _update_access_forward_grants(a_c_ops[sop])
        end
      end

      # Get the access checker configuration for an operation.
      #
      # @param op [Symbol, String] The name of the operation for which to get the checker configuration.
      #
      # @return Returns an [Fl::Framework::Access::Checker] instance containing the configuration for +op+,
      #  +nil+ if not found.

      def config_for_op(op)
        s = op.to_sym
        ops = access_control_ops()
        if ops.has_key?(s)
          ops[s]
        else
          nil
        end
      end

      # Check if an actor has permission to perform an operation on a class.
      # The object in _actor_ requests permission to perform the operation _op_ on the class, rather
      # than a specific object; for example, the +:index+ operation falls under this category.
      # See the documentation for the instance method by the same name.
      #
      # @param actor [Object] The actor requesting permission.
      # @param op [Symbol, String] The requested operation.
      # @param context The context in which to do the check; this is typically used with nested resources,
      #  where a class operation (say, +:index+) is performed in the context of a nesting resource (for 
      #  example, indexing the comments associated with an asset). In that case, we need to specify
      #  the instance of the nesting class.
      #
      # @return [Symbol, nil, false] If _actor_ can perform the operation on the object, the return
      #  value is a symbol; the actual values returned are implementation-dependent, but the fact that a
      #  symbol is returned implies that permission was granted.
      #  If access rights were not granted, +nil+ is returned.
      #  Under some circumstances, +false+ may be returned to indicate an error while determining access;
      #  this *must* be interpreted as a denial of grants.

      def permission?(actor, op, context = nil)
        p = self.config_for_op(op)
        if p
          p.run_check(self, actor, context)
        else
          default_access_checker(Checker.new(op.to_sym, :default_access_checker, {}), self, actor, context)
        end
      end

      # An alias for {#permission?}.

      def execute?(actor, op, context = nil)
        permission?(actor, op, context)
      end

      # An alias for {#permission?}.

      def operate?(actor, op, context = nil)
        permission?(actor, op, context)
      end

      # The default access rights checker.
      # This is the access checker that is registered with the standard permission checks;
      # it is the heart of the access control mechanism.
      #
      # The default implementation is rather restrictive: it simply returns +nil+ to indicate that
      # no access has been granted. Classes or modules that include the access control framework module
      # are expected to override it.
      #
      # The parameters for this method originate from those in the call to a permission checker like
      # {#permission?}:
      # - _op_ is the resolved operation from the permission function's _op_ parameter.
      # - _obj_ is the object calling the permission function.
      # - _actor_ is the requesting actor from the permission function's _actor_ parameter.
      # - _context_ is the call context from the permission function's _context_ parameter.
      # For example, consider this call:
      #     myobj = get_some_object()
      #     myactor = get_the_actor()
      #     if myobj.permission?(myactor, Fl::Framework::Access::Grants::READ, { key: 'value' })
      #       myobj.do_some_work()
      #     end
      # In this case, {#default_access_checker} is called with _op_ set to the data corresponding
      # to {Fl::Framework::Access::Grants::READ}, _obj_ set to <tt>myobj</tt>,
      # _actor_ set to <tt>myactor</tt>, and _context_ set to <tt>{ key: 'value' }</tt>.
      #
      # @param op [Fl::Framework::Access::Access::Checker] The requested operation.
      # @param obj [Object] The target of the request.
      # @param actor [Object] The actor requesting permission.
      # @param context The context in which to do the check.
      #
      # @return [Symbol, nil, Boolean] An operational default access checker is expected to return a symbol if
      #  access rights were granted. It returns +nil+ if access grants were not granted.
      #  Under some conditions, it may elect to return +false+ to indicate that there was some kind of error
      #  when checking for access; a +false+ return value indicates that access rights were not granted,
      #  and it *must* be interpreted as such.

      def default_access_checker(op, obj, actor, context = nil)
        return nil
      end

      private

      def _update_access_forward_grants(checker)
        # We only need to do this if this object also manages access grants; not all classes that
        # implement access control also manage grants (see, for example, Fl::Core::AccessKey)

        if self.respond_to?(:access_control_forward_grants)
          a_c_f = self.access_control_forward_grants
          checker.grants.each do |fg|
            if a_c_f.has_key?(fg)
              a_c_f[fg] = a_c_f[fg] | [ checker.op ]
            else
              a_c_f[fg] = [ checker.op ]
            end
          end
        end
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # The default access checker, as an instance method.
      # This implementation simply calls the class method by the same name.
      # See the documentation for {Fl::Framework::Access::Access::ClassMethods#default_access_checker}.
      #
      # Note that this is typically *not* the access checker method you want to override; instead, you
      # should override the class method, where all access checks can be centralized.

      def default_access_checker(obj, actor, op, context = nil)
        self.class.default_access_checker(obj, actor, op, context)
      end

      # Check if this object is visible to an actor.
      # This method is currently a wrapper around {#permission?} using the +:read+ operation.
      #
      # @param actor [Object] The actor for which to check visibility; if this is +nil+, there is no
      #  actor and only publicly visible objects are visible.
      #
      # @return If the internal call to #permission? returns a non-+nil+ value, returns +true+; otherwise,
      #  return +false+.

      def visible?(actor)
        return permission?(actor, Fl::Framework::Access::Grants::READ).nil? ? false : true
      end

      # Check if an actor has permission to perform an operation on an object.
      # The _actor_ requests permission to perform the operation _op_ on +self+.
      # The set of operations includes the following default values:
      # - *:read* Access the object's contents.
      # - *:write* Make changes to the object.
      # - *:admin* Grant administrator rights on the object; this includes *:read* and *:write*.
      # - *:destroy* Destroy the object. Uses the same permission algorithm as *:write*.
      # - *:index* List objects. Note that *:index* does not request access for a specific instance,
      #   but rather for a class of objects. Therefore, one uses the class object in the call.
      # Clients of this module can use the {Fl::Framework::Access::Access::ClassMethods#access_op}
      # class method to register new operations (or to overwrite the default access check for the standard
      # operations).
      #
      # @param actor [Object] The actor requesting permissions.
      # @param op [Symbol, String] The name of the requested operation.
      # @param context Additional context information for the call. For example, the comment checks
      #  call the commentable's +permission?+ method, passing the comment in the context.
      #
      # @return [Symbol, nil, false] If _actor_ can perform the operation on the object, the return
      #  value is a symbol; the actual values returned are implementation-dependent, but the fact that a
      #  symbol is returned implies that permission was granted.
      #  If access rights were not granted, +nil+ is returned.
      #  Under some circumstances, +false+ may be returned to indicate an error while determining access;
      #  this *must* be interpreted as a denial of grants.

      def permission?(actor, op, context = nil)
        p = self.class.config_for_op(op)
        if p
          p.run_check(self, actor, context)
        else
          default_access_checker(Checker.new(op.to_sym, :default_access_checker, {}), self, actor, context)
        end
      end

      private
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.
    # - Defines and registers the following default operations and access checkers:
    #   - +:index+ with checker +:default_access_checker+ and context +:class+.
    #   - +:create+ with checker +:default_access_checker+ and context +:class+.
    #   - +:read+ with checker +:default_access_checker+ and context +:instance+.
    #     This operation allows +:public+ access.
    #   - +:write+ with checker +:default_access_checker+ and context +:instance+.
    #     This operation also grants +:read+ access.
    #   - +:destroy+ with checker +:default_access_checker+ and context +:instance+.
    #   - +:admin+ with checker +:default_access_checker+ and context +:instance+.
    #     This operation also grants +:read+ and +:write+ access.
    # Since initially +:default_access_checker+ maps to either {ClassMethods#default_access_checker}
    # or {InstanceMethods#default_access_checker}, by default no permissions are granted: this forces classes
    # that include {Fl::Framework::Access::Access} to override the access policies as needed.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
        # Get the registered operations.
        # Returns a Hash where the keys are operation nmes (as Symbol), and the values the corresponding
        # Fl::Framework::Access::Checker instance.

        def access_control_ops()
          s = self
          until s.instance_variable_defined?(:@access_control_ops)
            s = s.superclass
          end
          s.instance_variable_get(:@access_control_ops)
        end
      end

      base.class_eval do
        include InstanceMethods

        @access_control_ops = {}

        access_op(Fl::Framework::Access::Grants::INDEX, :default_access_checker, { context: :class })
        access_op(Fl::Framework::Access::Grants::CREATE, :default_access_checker, { context: :class })
        access_op(Fl::Framework::Access::Grants::READ, :default_access_checker, {
                    context: :instance, public: true })
        access_op(Fl::Framework::Access::Grants::WRITE, :default_access_checker, {
                    context: :instance, grants: [ Fl::Framework::Access::Grants::READ ] })
        access_op(Fl::Framework::Access::Grants::DESTROY, :default_access_checker, { context: :instance })
        access_op(Fl::Framework::Access::Grants::ADMIN, :default_access_checker, {
                    context: :instance,
                    grants: [ Fl::Framework::Access::Grants::READ, Fl::Framework::Access::Grants::WRITE ]
                  })
        access_op(Fl::Framework::Access::Grants::OWNER, :default_access_checker, {
                    context: :instance, 
                    grants: [ Fl::Framework::Access::Grants::READ, Fl::Framework::Access::Grants::WRITE,
                              Fl::Framework::Access::Grants::DESTROY ]
                  })

        alias accessible? visible?
        alias execute? permission?
        alias operate? permission?
      end
    end
  end
end
