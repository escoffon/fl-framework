module Fl::Framework::Access
  # Access APIs.
  # This module defines two main classes of methods:
  # 1. Class methods to register new access checkers, or to override existing ones.
  #    See {Fl::Framework::Access::Access::ClassMethods#access_op}.
  # 2. Instance (and class) methods to check if an actor has access to an object.
  #    See {Fl::Framework::Access::Access::InstanceMethods#permission?} and
  #    {Fl::Framework::Access::Access::ClassMethods#default_access_checker}.

  module Access
    # A class to store access check information.
    # Instances of this class contain information about an operation.
    # See the documentation for Fl::Framework::Access::ClassMethods#access_op for details.
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
      # @param checker The name of the check method or body of the check Proc.
      # @param config [hash] A Hash of configuration parameters.
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

      # @!attribute [r]
      # @return [Symbol] the execution context for this access check.

      def context()
        return (@config.has_key?(:context)) ? @config[:context] : :instance
      end

      # @!attribute [r]
      # @return [Array<Symbol>] the list of permissions that are implicitly granted by thie access check;
      #  for example, a +:write+ permission also grants :+read+ permission.

      def grants()
        return (@config[:grants].is_a?(Array)) ? @config[:grants] : []
      end

      # @!attribute [r]
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
      # @param actor [Fl::Core::Actor]: The actor requesting access.
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
      # - *actor* The instance of {Fl::Core::Actor} (the actor) requesting permission.
      # - *ctx* The context that was passed to the permission call.
      # If we compare these to the arguments to the {Fl::Framework::Access::InstanceMethods#permission?} method, then:
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
      # The return value of the checker is one of the following symbols if the access rights are granted:
      # - +:private+ The +actor+ owns the object.
      # - +:group+ The +actor+ is a member of one of the owner's groups.
      # - +:friends+ The +actor+ is a member of one of the owner's friends.
      # - +:public+ The object (+self+) is publicly accessible.
      # Otherwise, the return value is +nil+ to indicate that access rights were not granted.
      # Under some circumstances, the checker may elect to return +false+ to indicate that access was not
      # granted because of an error.
      # This value is returned by {Fl::Framework::Access::InstanceMethods#permission?}.
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
      # @param actor [Fl::Core::Actor] The actor requesting permission; this is typically a [Fl::Core::User].
      # @param op [Symbol, String] The requested operation.
      # @param context The context in which to do the check; this is typically used with nested resources,
      #  where a class operation (say, +:index+) is performed in the context of a nesting resource (for 
      #  example, indexing the comments associated with an asset). In that case, we need to specify
      #  the instance of the nesting class.
      #
      # @return [Symbol, nil, +false+] If +actor+ can perform the operation on the object, based on ownership,
      #  access grants, and visibility attributes, returns the visibility level that allowed the operation:
      #  - +:private+ The +actor+ owns the object.
      #  - +:group+ The +actor+ is a member of one of the owner's groups.
      #  - +:friends+ The +actor+ is a member of one of the owner's friends.
      #  - +:public+ The object (+self+) is publicly accessible.
      #  Otherwise, the return value is +nil+ to indicate that access rights were not granted.
      #  Under some circumstances, +false+ may be returned to indicate an error while determining access;
      #  this *must* be interpreted as a denial of grants.

      def permission?(actor, op, context = nil)
        p = self.config_for_op(op)
        if p
          p.run_check(self, actor, context)
        else
          default_access_checker(Checker.new(op.to_sym, :default_access_checker, {}),
                                 self, actor, context)
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

      # The standard access rights checker.
      # The standard access rights grant algorithm defines the following rules:
      # - An object with private visibility grants rights only to its owners.
      # - An object with group visibility grants rights to members of the owners' groups.
      #   The list of access grants restricts both the groups whose members will be granted rights,
      #   and the rights themselves. For example, if the grants are +:read+ to +group1+ and +:write+
      #   to +group2+, members of +group1+ and +group2+ are granted +:read+ access, and members of
      #   +group2+ are also granted +:write+. (+group2+ is granted +:read+ access because +:write+
      #   is a forward grant for +:read+.)
      # - An object with group visibility grants rights to members of the owners' groups and to members
      #   of groups linked with the owners' groups. The list of access grants restricts groups and rights
      #   as described above.
      # - An object with public visibility grants rights to anyone, but the right being requested must
      #   have allowed public access (for example, the +:write+ grant does not allow public access, so
      #   that public visibility objects cannot be modified by anyone).
      # - An object with direct visibility grants rights to anyone, but restricted to the object's access
      #   rights. This visibility can be use to grant access to arbitrary actors, for example to groups
      #   or individual users that are not in the owner's groups or friends.
      # The method implements these rules as follows:
      # 1. If the access grants or visibility for _obj_ have changed, and _obj_ has not been saved,
      #    return +false+. This is done to ensure that _obj_ is in a consistent and valid state when
      #    access is checked.
      # 2. If _actor_ is +nil?+, return +nil+ unless the object's visibility is {Fl::Framework::Visibility::PUBLIC}.
      #    If _obj_ has public visibility, run the same check as in 5., below.
      # 3. If _actor_ is one of of the owners of _obj_, returns {Fl::Framework::Visibility::PRIVATE}, since owners
      #    have full access for any operation.
      # 4. If the object visibility is {Fl::Framework::Visibility::PRIVATE}, return +nil+, since _actor_ is not an
      #    owner, and the object is only accessible to owners.
      # 5. If the object visibility is {Fl::Framework::Visibility::PUBLIC}, check if _op_ allows public access
      #    (the +public+ attribute is +true+), and if so return {Fl::Framework::Visibility::PUBLIC}.
      #    Otherwise, look at the forward grants for _op_ (the list of other registered operations that
      #    grant _op_.op access), and check if any of them allow public access: if so, return 
      #    {Fl::Framework::Visibility::PUBLIC}. If all checks fail, return +nil+.
      # 6. For {Fl::Framework::Visibility::GROUP} visibility, first iterate over all access grants associated with _obj_
      #    (if _obj_ responds to {Fl::Framework::Access::Grants::InstanceMethods#access_grants}).
      #    If the grant's operation matches _op_.op, and the grantee matches _actor_, return
      #    {Fl::Framework::Visibility::GROUP}. If _actor_ is a user and the grantee is a group, check if _actor_ is
      #    a member of the grantee group; if so, return {Fl::Framework::Visibility::GROUP}.
      #    If there was no match with _op_.op, try all the forward grants and return {Fl::Framework::Visibility::GROUP}
      #    if any of the forward grant checks return non-nil.
      #    Note that the object's access grants are in a valid state as determined in step 1., and therefore
      #    all groups in the access grants are owners' groups; therefore, _actor_ is granted access only if
      #    it is a member of the owners' groups that are granted access.
      # 7. The algorithm for {Fl::Framework::Visibility::FRIENDS} visibility is the same as for {Fl::Framework::Visibility::GROUP}.
      #    The only difference is that the access grants now may include groups that are linked to the
      #    owners' groups.
      #    Note that the object's access grants are in a valid state as determined in step 1., and therefore
      #    all groups in the access grants are either owners' groups, or linked to owners' groups; therefore,
      #    _actor_ is granted access only if it is a member of the owners' groups or owners' friends that
      #    are granted access.
      # 8. The algorithm for {Fl::Framework::Visibility::DIRECT} visibility is also the same as for
      #    {Fl::Framework::Visibility::GROUP}.
      #    The only difference is that the access grants now may include arbitrary actors.
      #
      # @param op [Fl::Framework::Access::Checker] An instance of {Fl::Framework::Access::Checker} that describes
      #  the access check configuration in use.
      #  If the operation has not been registered, this is a fabricated (and temporary) object;
      #  otherwise it is one of the registered operations.
      # @param obj The object that grants or denies access rights.
      # @param actor [Fl::Core::Actor] The object requesting the access rights.
      # @param context Additional context passed to {#permission?}.
      #
      # @return Returns a Symbol corresponding to the visibility lavel for which access was granted.
      #  If access was denied, the return value is +nil+. If the access rights or the visibility are
      #  marked changed, the return value is +false+; see below for a discussion of why this is done.
      #
      # This method uses a Template Method pattern; it calls +visibility+ to obtain the object's
      # visibility setting, {Fl::Framework::Access::InstanceMethods#access_grants} to obtain the list of actors that
      # were grantes some access to the object, +owners+ to obtain the actors that own the object.
      #
      # It is possible for the object to be set up in an (invalid) state that gives more access than the
      # object's visibility setting. For example, when the visibility is set to +:group+, a valid object
      # includes only owner groups in the access rights, because of the semantics of +:group+ visibility;
      # this condition is enforced by a validation callback installed by {Fl::Framework::Access}.
      # In order to speed up access determination, the default checker does not confirm that the current
      # state of the object is consistent with the visibility settings, so that a client could add access
      # rights to, say, an arbitrary group and gain access to the object.
      # In order to prevent this, the checker code returns +false+ if it detects that the visibility
      # or the access grants have been modified and not saved to persistent storage. This forces clients to
      # save the object, which is possible only with valid contents.
      # Of course this is somewhat specious, since a malicious client coul just bypass the access control
      # layer altoghether, but at least it makes us feel good about ourselves that we did the right thing.

      def default_access_checker(op, obj, actor, context = nil)
        return false if obj.access_grants_changed? || obj.visibility_changed?

        # a nil actor makes access checks a lot less complex, since only objects with :public
        # visibility can be accessible. An object is publicly accessible if it has an access grant
        # for _op_ to the public group. A :public access grant is equivalent to a :read operation.

        if actor.nil?
          # a :public object is accessible only if the operation or forwarded operations allow :public
          # access, and if the object visibility is :public

          return nil unless obj.visibility == Fl::Framework::Visibility::PUBLIC

          # This is a duplicate of the :public visibility branch below; see the discussion of access grants
          # there for some additional work that should be done, for example to grant access on an object
          # by object basis (say, to make object O writeable publicly).

          return Fl::Framework::Visibility::PUBLIC if op.public

          forward_grants_for_op(op.op).each do |f|
            f_op = config_for_op(f)
            return Fl::Framework::Visibility::PUBLIC if f_op && f_op.run_check(obj, actor, context)
          end

          return nil
        end

        # owners have full access. we check the grants first, and then the owners

        if obj.respond_to?(:access_grants)
          sop = op.op
          obj.access_grants.each do |aa|
            if (aa.rel.grant.to_sym == :owner) && (aa.actor.id == actor.id)
              return Fl::Framework::Visibility::PRIVATE
            end
          end
        else
          obj.owners.each do |o|
            return Fl::Framework::Visibility::PRIVATE if o.id == actor.id
          end
        end

        case obj.visibility
        when Fl::Framework::Visibility::PRIVATE
          # since actor is not an owner, and the object has :private visibility, there is no access

          return nil
        when Fl::Framework::Visibility::GROUP, Fl::Framework::Visibility::FRIENDS, Fl::Framework::Visibility::DIRECT
          # a :group object is accessible if it grants op.op access to the actor, and if the access is
          # granted to one of actor's groups.
          # A valid _obj_ includes only groups and users from the owners, so we don't check here.
          #
          # a :friends object is accessible with the same algorithm, except that now we allow both owners'
          # groups and owners' friends.
          # Again, a valid object includes only groups and friends from the owners.
          #
          # a :direct object uses the same check as :group and :public; in this case, any actor can be in
          # the access grants, but the algorithm is the same

          if obj.respond_to?(:access_grants)
            sop = op.op
            obj.access_grants.each do |aa|
              if aa.rel.grant.to_sym == sop
                if aa.actor.id == actor.id
                  return obj.visibility
                elsif aa.actor.is_a?(Fl::Core::Group) && actor.is_a?(Fl::Core::User)
                  if aa.actor.has_role?(actor, [Fl::Core::Group::ROLE_MEMBER, Fl::Core::Group::ROLE_ADMIN])
                    return obj.visibility
                  end
                end
              end
            end
          end
          
          # If we are here, no direct grant was found. Let's see if we can find a forward grant

          forward_grants_for_op(op.op).each do |f|
            f_op = config_for_op(f)
            return obj.visibility if f_op && f_op.run_check(obj, actor, context)
          end

          return nil
        when Fl::Framework::Visibility::PUBLIC
          # a :public object is accessible only if the operation or forwarded operations allow :public access

          # but we should filter by access grants: if the object defines access grants, we grant access only
          # if the grant is present. In other words, if the operation allows :public access, and there are
          # grants present, then we grant access only if the grant allow the operation. This makes it possible
          # to mark something :public and then restrict access to a subset of users or groups.
          # I'm not sure that there is another way to address the following problem: I want to grant :read
          # access to object O to group G which is not one of my groups.
          # But I think that granting access to group G directly should cover that...
          # These notes are here to remind me to tackle the problem.

          return Fl::Framework::Visibility::PUBLIC if op.public

          forward_grants_for_op(op.op).each do |f|
            f_op = config_for_op(f)
            return Fl::Framework::Visibility::PUBLIC if f_op && f_op.run_check(obj, actor, context)
          end

          return nil
        end

        # nothing worked

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

      def default_access_checker(obj, actor, op, context = nil)
        self.class.default_access_checker(obj, actor, op, context)
      end

      # Check if this object is visible to an actor.
      # This method is currently a wrapper around {#permission?} using the +:read+ operation.
      #
      # @param actor [Fl::Core::Actor] The actor for which to check visibility; if this is +nil+, there is no
      #  actor and only +:public+ objects are visible.
      #
      # @return If the internal call to #permission? returns a non-+nil+ value, returns +true+; otherwise,
      #  return +false+.

      def visible?(actor)
        return permission?(actor, Fl::Framework::Access::Grants::READ).nil? ? false : true
      end

      # @!visibility private
      # Tag-based visibility check.
      # This method checks if the user's tags (if any) allow or prohibit visibility to self, based
      # on self's white and black lists. The algorithm is as follows:
      # 1. if the object's tag list ie empty, check the whitelist: if the whitelist is also empty,
      #    then the object is visible. If the whitelist is nonempty, the object is not visible,
      #    since no tags match those in the whitelist (there are no tags).
      # 2. If the object's tag list is nonempty, check the blacklist:
      #    a. The blacklist is empty: move to step 3, where we check the whitelist.
      #    b. The blacklist is nonempty: if any of the object's tags are in
      #       the blacklist, the object is not visible.
      #       Otherwise, move to step 3, where we check the whitelist.
      # 3. Now check the whitelist:
      #    a. If the whitelist is empty, the object is visible.
      #    b. If the whitelist is nonempty, the object is visible only if one of its tags is in the
      #       whitelist.
      # This algorithm has the following characteristics:
      # 1. If both blacklist and whitelist are empty, no tag-based access control is done.
      #    Essentially, we assume that empty lists mean "don't do tag-based access control."
      # 2. If the user's tag list is empty, the only tag-based access is based on whitelists, and
      #    it is quite restrictive: if the whitelist is nonempty, access is denied.
      #    The reason for this behavior is that whitelists are restrictive by nature, since they
      #    specify the class of users who have explicit access to the object; therefore, the algorithm
      #    is as restrictive as the intended purpose of whitelisting.
      #    Note also that blacklists are ignored; this is also as expected, based on the semantics of
      #    a blacklist.
      # 3. With a nonempty user's tag list, blacklists are checked first, and therefore override
      #    possible permissions from whitelists. For example, if the user's tag list is [ tag1 ],
      #    and the object's blacklist and whitelist are [ tag1 ] and [ tag1 ], respectively, then
      #    access is denied. Note that this is not a common (or logical!) situation.
      #
      # visibility:: The visibility to return on success.
      # actor:: The actor to check (may be +nil+).
      #
      # Returns the value of the visibility argument if the tags lists allow it, or +nil+ otherwise.
      #
      # @note This method is temporarily disabled, until we reintroduce tags in the Neo4j DB.

      def check_tags(visibility, actor)
        return visibility

        actor_tags = if actor
                       actor.tag_names
                     else
                       []
                     end

        if actor_tags.length > 0
          # OK, so this actor has tags. If any of the actor tags are in the blacklist, we fail

          blacklist = self.blacktag_names
          if blacklist.length > 0
            actor_tags.each do |t|
              return nil if blacklist.include?(t)
            end
          end

          # If none of the actor tags are in the whitelist, we fail

          whitelist = self.whitetag_names
          if whitelist.length > 0
            actor_tags.each do |t|
              return visibility if whitelist.include?(t)
            end

            nil
          else
            visibility
          end
        else
          # if no actor tags, the blacklist does not apply.
          # If the whitelist is nonempty, then the object is not visible to this actor, since no actor
          # tags match an entry in the whitelist

          return (self.whitetags.length > 0) ? nil : visibility
        end
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
      # However, clients of this module can use the {Fl::Framework::Access::Access::ClassMethods#access_op} class
      # method to register new operations (or to overwrite the default access check for the standard
      # operations).
      #
      # @param actor [Fl::Core::Actor] The actor requesting permissions.
      # @param op [Symbol, String] The name of the requested operation.
      # @param context Additional context information for the call. For example, the comment checks
      #  call the commentable's +permission?+ method, passing the comment in the context.
      #
      # @return If _actor_ can perform the operation on the object, based on ownership, access grants,
      #  and visibility attributes, returns the visibility level that allowed the operation:
      #  - *:private* The _actor_ owns the object.
      #  - *:group* The _actor_ is a member of one of the owner's groups.
      #  - *:friends* The _actor_ is a member of one of the owner's friends.
      #  - *:public* The object (+self+) is publicly accessible.
      #  Otherwise, the return value is +nil+ to indicate that access rights were not granted.

      def permission?(actor, op, context = nil)
        p = self.class.config_for_op(op)
        if p
          p.run_check(self, actor, context)
        else
          default_access_checker(Checker.new(op.to_sym, :default_access_checker, {}),
                                 self, actor, context)
        end
      end

      private

      def _clear_access_relationships()
        if self.persisted?
          self.query_as(:o)\
            .match('(o)-[r:ACCESS]->(a)')\
            .where('(r.grant <> {owner_grant})', owner_grant: Fl::Framework::Access::Grants::OWNER)\
            .delete(:r)\
            .exec
        end
      end

      def _access_owner_groups(reload = false)
        if reload || @access_owner_groups.nil?
          @access_owner_groups = []
          gids = {
            Fl::Core::Group.public_group.id => true
          }
          self.owners.each do |o|
            o.groups.each do |g|
              unless gids.has_key?(g.id)
                @access_owner_groups << g
                gids[g.id] = true
              end
            end
          end
        end
        @access_owner_groups
      end

      def _access_owner_friends(reload = false)
        if reload || @access_owner_friends.nil?
          @access_owner_friends = []
          gids = {
            Fl::Core::Group.public_group.id => true
          }
          self.owners.each do |o|
            o.groups.each do |g|
              g.friends.each do |f|
                unless gids.has_key?(f.id)
                  @access_owner_friends << f
                  gids[f.id] = true
                end
              end
            end
          end
        end
        @access_owner_friends
      end

      def _clear_owner_caches()
        @access_owner_groups = nil
        @access_owner_friends = nil
      end

      def _clear_caches()
        _clear_access_caches() if respond_to?(:_clear_access_caches, true)
        _clear_owner_caches()
      end
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.
    # - Defines and registers the following default operations and access checkers:
    #   - +:index+ with checker #access_op_index and context +:class+
    #   - +:create+ with checker #access_op_create and context +:class+
    #   - +:read+ with checker #default_access_checker and context +:instance+.
    #     This operation allows +:public+ access.
    #   - +:write+ with checker #default_access_checker and context +:instance+.
    #     This operation also grants +:read+ access.
    #   - +:destroy+ with checker #default_access_checker and context +:instance+.
    #   - +:admin+ with checker #default_access_checker and context +:instance+.
    #     This operation also grants +:read+ and +:write+ access.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
        # The default access checker method for +:index+.
        # The default policy is open access to anyone.
        #
        # op: The operation configuration.
        # obj:: The object for which to check for access.
        # actor:: The actor requesting the access.
        # context:: The context in which to do the check.
        #
        # Returns a symbol corresponding to the access level granted, or nil if access was denied.

        def self.access_op_index(op, obj, actor, context = nil)
          :public
        end

        # The default access checker method for +:create+.
        # The default policy is open access to anyone, but only if logged in.
        #
        # op: The operation configuration.
        # obj:: The object for which to check for access.
        # actor:: The actor requesting the access.
        # context:: The context in which to do the check.
        #
        # Returns a symbol corresponding to the access level granted, or nil if access was denied.

        def self.access_op_create(op, obj, actor, context = nil)
          (actor.nil?) ? nil : :public
        end

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

        access_op(Fl::Framework::Access::Grants::INDEX, :access_op_index, { context: :class })
        access_op(Fl::Framework::Access::Grants::CREATE, :access_op_create, { context: :class })
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

        alias _original_reload reload

        # Extends the base +:reload+ method to clear the access caches.

        def reload()
          _original_reload()
          _clear_caches()
        end
      end
    end
  end
end
